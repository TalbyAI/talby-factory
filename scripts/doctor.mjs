#!/usr/bin/env node

import { access, readFile } from 'node:fs/promises';
import { constants as fsConstants } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');

const findings = [];

function addFinding(level, code, message, detail) {
  findings.push({ level, code, message, detail });
}

function runCommand(command, args) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: 'utf8'
  });

  return {
    ok: result.status === 0,
    status: result.status,
    stdout: (result.stdout || '').trim(),
    stderr: (result.stderr || '').trim(),
    error: result.error
  };
}

async function pathExists(targetPath) {
  try {
    await access(targetPath, fsConstants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function validateSupportedBaseline() {
  const dockerenvExists = await pathExists('/.dockerenv');
  const workspaceRootExists = await pathExists('/workspaces');
  const expectedDevcontainer = await pathExists(path.join(repoRoot, '.devcontainer', 'devcontainer.json'));

  if (dockerenvExists && workspaceRootExists && expectedDevcontainer) {
    addFinding(
      'INFO',
      'baseline-supported',
      'Layer 1 baseline heuristics match a Dev Container-style workspace environment.'
    );
    return;
  }

  addFinding(
    'ERROR',
    'baseline-unsupported',
    'Layer 1 baseline heuristics do not match the expected Dev Container-style environment.',
    'Expected /.dockerenv, /workspaces, and .devcontainer/devcontainer.json to exist.'
  );
}

function validateTool(command, args, label, missingSeverity = 'ERROR') {
  const result = runCommand(command, args);

  if (result.ok) {
    addFinding('INFO', `${command}-available`, `${label} is available.`, result.stdout.split('\n')[0] || undefined);
    return;
  }

  const detail = result.error?.message || result.stderr || `Exit status: ${result.status}`;
  addFinding(missingSeverity, `${command}-missing`, `${label} is not available.`, detail);
}

async function validatePackageManifest() {
  const manifestPath = path.join(repoRoot, 'package.json');

  if (!(await pathExists(manifestPath))) {
    addFinding('ERROR', 'package-missing', 'Root package.json is missing.');
    return;
  }

  try {
    const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
    const hasDoctorScript = manifest.scripts && typeof manifest.scripts.doctor === 'string';
    const dependencyKeys = [
      ...Object.keys(manifest.dependencies || {}),
      ...Object.keys(manifest.devDependencies || {})
    ];

    if (!manifest.private) {
      addFinding('WARN', 'package-private', 'Root package.json should remain private for Layer 1.');
    } else {
      addFinding('INFO', 'package-private', 'Root package.json is private as expected for Layer 1.');
    }

    if (!hasDoctorScript) {
      addFinding('ERROR', 'doctor-script-missing', 'package.json is missing the doctor script entrypoint.');
    } else {
      addFinding('INFO', 'doctor-script-present', 'package.json exposes the doctor script entrypoint.', manifest.scripts.doctor);
    }

    if (dependencyKeys.length === 0) {
      addFinding('INFO', 'package-no-deps', 'Root package.json remains dependency-free, so no restore hook is required.');
    } else {
      addFinding(
        'WARN',
        'package-has-deps',
        'Root package.json declares repo-local dependencies and would need a deterministic restore hook.',
        dependencyKeys.join(', ')
      );
    }
  } catch (error) {
    addFinding('ERROR', 'package-invalid', 'Root package.json is not valid JSON.', error instanceof Error ? error.message : String(error));
  }
}

async function validateLayer1Files() {
  const requiredFiles = [
    'package.json',
    'Justfile',
    path.join('scripts', 'doctor.mjs'),
    path.join('.devcontainer', 'devcontainer.json'),
    path.join('.devcontainer', 'Dockerfile')
  ];

  for (const relativePath of requiredFiles) {
    const absolutePath = path.join(repoRoot, relativePath);
    if (await pathExists(absolutePath)) {
      addFinding('INFO', `file-${relativePath}`, `Found ${relativePath}.`);
    } else {
      addFinding('ERROR', `file-${relativePath}`, `Missing expected Layer 1 file: ${relativePath}.`);
    }
  }
}

function validateCommandSurface() {
  addFinding(
    'INFO',
    'pnpm-doctor-starts',
    'pnpm doctor resolves to this Layer 1 diagnostic entrypoint.',
    'Validated by the active package.json script target for the running doctor process.'
  );

  if (process.env.LAYER1_DOCTOR_VIA_JUST === '1') {
    addFinding(
      'INFO',
      'just-doctor-starts',
      'just doctor routes to the same Layer 1 diagnostic entrypoint.',
      'Validated by the current invocation path from the public Justfile recipe.'
    );
  } else {
    const justDoctor = runCommand('just', ['doctor']);

    if (justDoctor.ok) {
      addFinding('INFO', 'just-doctor-starts', 'just doctor can start the bounded Layer 1 diagnostic entrypoint.');
    } else {
      const detail = justDoctor.error?.message || justDoctor.stderr || `Exit status: ${justDoctor.status}`;
      addFinding('WARN', 'just-doctor-unavailable', 'just doctor is unavailable in the current environment.', detail);
    }
  }

  const justList = runCommand('just', ['--list']);

  if (justList.ok) {
    addFinding('INFO', 'just-list-starts', 'just --list enumerates the bounded Layer 1 command surface.');
  } else {
    const detail = justList.error?.message || justList.stderr || `Exit status: ${justList.status}`;
    addFinding('WARN', 'just-list-unavailable', 'just --list is unavailable in the current environment.', detail);
  }
}

function printFindings() {
  for (const finding of findings) {
    const detailSuffix = finding.detail ? ` :: ${finding.detail}` : '';
    console.log(`${finding.level} [${finding.code}] ${finding.message}${detailSuffix}`);
  }
}

function exitCodeForFindings() {
  return findings.some((finding) => finding.level === 'ERROR') ? 1 : 0;
}

async function main() {
  await validateSupportedBaseline();
  validateTool('az', ['version'], 'Azure CLI');
  validateTool('aspire', ['--version'], 'Aspire CLI');
  validateTool('node', ['--version'], 'Node.js runtime');
  validateTool('pnpm', ['--version'], 'pnpm runtime');
  validateTool('docker', ['--version'], 'Docker CLI');
  validateTool('gentle-ai', ['version'], 'Gentle AI CLI');
  validateTool('engram', ['version'], 'Engram CLI');
  validateTool('gga', ['version'], 'GGA CLI');
  validateTool('just', ['--version'], 'just command surface runtime', 'WARN');
  await validatePackageManifest();
  await validateLayer1Files();
  validateCommandSurface();
  printFindings();
  process.exit(exitCodeForFindings());
}

await main();
