#!/usr/bin/env bun

import { spawnSync } from "node:child_process"
import { chmod, copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import { build } from "vite"
import { Script } from "@opencode/script"
import { embed } from "@opencode/script/highlights"
import pkg from "../package.json"
import { collectNodeAssets, copyNodeAssets, hashNodeAssets, seaAssetMap } from "./node-assets"
import { appArchiveAsset, mainConfig } from "../vite.node.config"
import { nodeTarget, type NodeTarget } from "../src/node/target"
import { buildAppArchive } from "./app-assets"
import { verifyArtifact } from "./verify-artifact"
import { NativeArch } from "../../../script/native-arch"
import { bundledModelsSnapshot } from "../../core/script/models-snapshot"

const dir = path.resolve(import.meta.dirname, "..")
const outdir = path.resolve(
  dir,
  process.argv.find((arg) => arg.startsWith("--outdir="))?.slice("--outdir=".length) ?? "dist/lexe",
)
if (outdir === dir) throw new Error("--outdir must not be the package directory")
if (outdir === path.join(dir, "dist-node")) {
  throw new Error("--outdir must not be dist-node because it contains temporary files")
}

const bundleOnly = process.argv.includes("--bundle-only")
const skipInstall = process.argv.includes("--skip-install")
const skipWebUi = process.argv.includes("--skip-web-ui")
const appArchiveOnly = process.argv.includes("--app-archive-only")
const highlights = Script.preview ? undefined : embed(process.env.OPENCODE_RELEASE_NOTES)
const requestedArchive = process.env.OPENCODE_APP_ARCHIVE
const archivePath = requestedArchive ? path.resolve(dir, requestedArchive) : undefined
const requested = process.env.OPENCODE_TARGET
const hostTarget = nodeTarget(process.platform, process.arch)
const allTargets = [
  nodeTarget("linux", "arm64"),
  nodeTarget("linux", "x64"),
  nodeTarget("darwin", "arm64"),
  nodeTarget("win32", "arm64"),
  nodeTarget("win32", "x64"),
]
const targets = requested
  ? allTargets.filter((target) => targetName(target) === requested)
  : [hostTarget]

const lexeBin = process.env.LEXE_BIN || "lexe"

process.chdir(dir)
if (!skipInstall) run(process.execPath, ["install", "--os=*", "--cpu=*"])
if (appArchiveOnly) {
  if (!archivePath) throw new Error("--app-archive-only requires OPENCODE_APP_ARCHIVE")
  await mkdir(path.dirname(archivePath), { recursive: true })
  await writeFile(archivePath, await buildAppArchive(Script.channel, Script.version, { skipBuild: skipWebUi }))
  process.exit(0)
}
if (targets.length === 0) {
  throw new Error(`Unknown lexe target: ${requested}`)
}

const modelsSnapshot = await bundledModelsSnapshot()
const appArchive = archivePath
  ? await Bun.file(archivePath).bytes()
  : await buildAppArchive(Script.channel, Script.version, { skipBuild: skipWebUi })
if (!bundleOnly) await rm(outdir, { recursive: true, force: true })

async function assertTextImportsInlined(bundlePath: string) {
  const bundle = await readFile(bundlePath, "utf8")
  const markers = [
    { marker: '"zhipuai"', source: "models-dev snapshot" },
    { marker: "/assets/snapshot", source: "models-dev snapshot inlined as asset URL", forbidden: true },
    { marker: '="/assets/', source: "text import inlined as asset URL", forbidden: true },
  ]
  for (const { marker, source, forbidden } of markers) {
    const present = bundle.includes(marker)
    if (forbidden ? present : !present) {
      throw new Error(`${bundlePath}: ${source} — text imports are not inlined as content (marker ${marker})`)
    }
  }
}

for (const target of targets) {
  const host = target.platform === process.platform && target.arch === process.arch
  if (!bundleOnly && !host) {
    throw new Error(
      `lexe compile --executable builds for the host binary (${targetName(hostTarget)}); cannot build ${targetName(target)} on ${targetName(hostTarget)}`,
    )
  }

  console.log(`building cli-lexe-${targetName(target)}`)
  const assets = await collectNodeAssets(target)
  await rm("dist-node", { recursive: true, force: true })
  const assetHash = await hashNodeAssets(assets)
  const input = {
    version: Script.version,
    channel: Script.channel,
    highlights,
    modelsSnapshot,
    assetHash,
    target,
  }
  await copyNodeAssets(assets)
  await writeFile(path.join("dist-node", "assets", appArchiveAsset), appArchive)
  const viteConfig = mainConfig(input)
  await build({
    ...viteConfig,
    define: {
      ...viteConfig.define,
      // mainConfig targets the Node package; standalone Lexe binaries use the OpenCode CLI identity.
      OPENCODE_CLI_NAME: JSON.stringify("opencode"),
      OPENCODE_ARTIFACT: JSON.stringify("cli"),
    },
  })
  await assertTextImportsInlined("dist-node/opencode.mjs")
  if (bundleOnly) {
    await verifyArtifact("dist-node/opencode.mjs")
    continue
  }

  run(lexeBin, ["dist-node/opencode.mjs", "--version"])
  run(lexeBin, ["dist-node/opencode.mjs", "--help"])

  const name = `cli-lexe-${targetName(target)}`
  const binary = target.platform === "win32" ? "opencode.exe" : "opencode"
  const output = path.join(outdir, name, "bin", binary)
  await mkdir(path.dirname(output), { recursive: true })
  const config = {
    main: "dist-node/opencode.mjs",
    mainFormat: "module",
    output: path.relative(dir, output),
    disableExperimentalSEAWarning: true,
    assets: await seaAssetMap(),
  }
  await writeFile("dist-node/sea.json", `${JSON.stringify(config, null, 2)}\n`)
  run(lexeBin, ["compile", "--executable", "--sea-config", "dist-node/sea.json", "-o", output])
  if (target.platform !== "win32") await chmod(output, 0o755)
  await NativeArch.verify(output, target.arch)
  await writeFile(
    path.join(outdir, name, "package.json"),
    `${JSON.stringify(
      {
        name: `@opencode/${name}`,
        version: Script.version,
        license: pkg.license,
        repository: { type: "git", url: "git+https://github.com/anomalyco/opencode.git" },
        os: [target.platform],
        cpu: [target.arch],
      },
      null,
      2,
    )}\n`,
  )
  await verifyArtifact(path.join(outdir, name))
  await smoke(output)
}

async function smoke(output: string) {
  const root = await mkdtemp(path.join(os.tmpdir(), "opencode-lexe-smoke-"))
  try {
    const executable = path.join(root, path.basename(output))
    await copyFile(output, executable)
    if (process.platform !== "win32") await chmod(executable, 0o755)
    run(executable, ["--version"], root)
    run(executable, ["--help"], root)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
}

function targetName(target: NodeTarget) {
  return `${target.platform === "win32" ? "windows" : target.platform}-${target.arch}`
}

function run(command: string, args: readonly string[], cwd = dir) {
  const result = spawnSync(command, args, { cwd, stdio: "inherit", env: process.env })
  if (result.error) throw result.error
  if (result.status !== 0) throw new Error(`${command} exited with status ${result.status ?? "unknown"}`)
}
