#!/usr/bin/env node

const { spawn } = require("node:child_process");
const path = require("node:path");

const script = path.join(__dirname, "install.sh");
const args = process.argv.slice(2);

function run(bashBin) {
  const child = spawn(bashBin, [script, ...args], {
    stdio: "inherit",
  });

  child.on("exit", (code) => {
    process.exit(code ?? 1);
  });

  child.on("error", () => {
    // bash not found at this location, try next
    tryNext();
  });
}

const candidates = [];

if (process.platform === "win32") {
  candidates.push(
    path.join(process.env["ProgramFiles"] ?? "C:\\Program Files", "Git", "bin", "bash.exe"),
    path.join(process.env["LocalAppData"] ?? "", "Programs", "Git", "bin", "bash.exe"),
    "wsl.exe",
    "bash.exe",
  );
} else {
  candidates.push("bash");
}

let index = 0;

function tryNext() {
  if (index >= candidates.length) {
    console.error(
      "nerd-fonts-installer: bash not found. Please install bash or Git Bash (Windows).",
    );
    process.exit(1);
  }

  run(candidates[index++]);
}

tryNext();
