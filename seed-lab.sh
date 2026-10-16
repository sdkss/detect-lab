#!/usr/bin/env bash
# Seed the detection lab: commit and push the test files to your repo.
# Usage:  REPO=owner/detect-lab ./seed-lab.sh
set -euo pipefail

: "${REPO:?Set REPO=owner/repo (e.g. REPO=myuser/detect-lab)}"

echo "[*] Seeding lab files into current git repo for $REPO"
git add secrets src .github README-app.md
git commit -m "lab: seed test files (fake secrets + decoy source + canary workflow)"
git push

echo "[+] Seeded. The committed fake secrets may raise secret-scanning alerts"
echo "    on public repos (expected). Nothing here is a real credential."
