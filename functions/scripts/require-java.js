#!/usr/bin/env node
'use strict';

// Predeploy gate preflight.
//
// The Firestore emulator is a Java process. If Java is missing or too old the
// emulator fails with an opaque error that looks like a test failure, which
// would make a broken gate indistinguishable from a real security regression.
//
// This check runs BEFORE the emulator is started and fails with an actionable,
// platform-neutral message. It deliberately does NOT hardcode any JDK path:
// each developer and each CI runner is responsible for putting its own JDK on
// PATH (or setting JAVA_HOME). No Java runtime is vendored into this repository.
//
// Required: JDK 21 (the Firestore emulator and firebase-tools both support 11+,
// but 21 is what this project is verified against).

const REQUIRED_MAJOR = 21;

function javaVersion() {
  // firebase-tools spawns `java` resolved from PATH. JAVA_HOME alone is NOT
  // enough: the emulator will fail with "Could not spawn `java -version`"
  // even when JAVA_HOME points at a perfectly good JDK. So the gate checks
  // PATH resolution first, and only then falls back to JAVA_HOME for the
  // version query.
  const fs = require('fs');
  const path = require('path');
  const cp = require('child_process');
  const env = Object.assign({}, process.env);

  const onPath = cp.spawnSync(process.platform === 'win32' ? 'java.exe' : 'java', ['-version'], { encoding: 'utf8' });
  if (!onPath.error) {
    return { cmd: process.platform === 'win32' ? 'java.exe' : 'java', args: ['-version'], source: 'PATH' };
  }

  if (env.JAVA_HOME) {
    const exe = path.join(env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'java.exe' : 'java');
    if (fs.existsSync(exe)) return { cmd: exe, args: ['-version'], source: 'JAVA_HOME' };
  }

  return { cmd: 'java', args: ['-version'], source: null };
}

let raw = '';
let source = null;
try {
  const cp = require('child_process');
  const j = javaVersion();
  source = j.source;
  // `java -version` writes to stderr on every JDK.
  const res = cp.spawnSync(j.cmd, j.args, { encoding: 'utf8' });
  raw = `${res.stderr || ''}${res.stdout || ''}`;
  if (res.error) throw res.error;
} catch (err) {
  process.stderr.write(
    '\n[gate] FATAL: could not run `java -version`.\n' +
      `[gate]   reason: ${err.message}\n` +
      '[gate]   The Firestore emulator requires a JDK on PATH or JAVA_HOME.\n' +
      '[gate]   Install a JDK ' + REQUIRED_MAJOR + ' and re-run. Do not hardcode a machine-specific\n' +
      '[gate]   path; set JAVA_HOME in your own environment.\n\n'
  );
  process.exit(1);
}

// firebase-tools resolves java from PATH. If we only found it via JAVA_HOME the
// emulator would still fail, so fail here with a precise instruction instead.
if (source !== 'PATH') {
  process.stderr.write(
    '\n[gate] FATAL: a JDK was found via JAVA_HOME, but `java` is not on PATH.\n' +
      '[gate]   firebase-tools spawns `java` from PATH, so the Firestore emulator\n' +
      '[gate]   cannot start even though JAVA_HOME is set.\n' +
      '[gate]   Add "<JAVA_HOME>/bin" to PATH for this shell, e.g.\n' +
      (process.platform === 'win32'
        ? '[gate]     set PATH=%JAVA_HOME%\\bin;%PATH%\n'
        : '[gate]     export PATH="$JAVA_HOME/bin:$PATH"\n') +
      '\n'
  );
  process.exit(1);
}

const m = raw.match(/version "(\d+)(?:\.(\d+))?/);
if (!m) {
  process.stderr.write(`\n[gate] FATAL: could not parse the Java version from:\n${raw.trim()}\n\n`);
  process.exit(1);
}

const major = Number(m[1]);
const minor = m[2] === undefined ? '' : `.${m[2]}`;

if (major < REQUIRED_MAJOR) {
  process.stderr.write(
    `\n[gate] FATAL: JDK ${REQUIRED_MAJOR}+ is required by the Firestore emulator, found ${major}${minor}.\n\n`
  );
  process.exit(1);
}

process.stdout.write(`[gate] java preflight OK (${major}${minor}, resolved from PATH)\n`);