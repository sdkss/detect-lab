#!/usr/bin/env bash
# =============================================================================
#  GitHub Detection Lab - attack simulator
#  Runs 5 benign attack simulations against a repo you OWN, each clearly marked
#  so the resulting events are easy to find in your GitHub security/audit log.
#
#  Usage:
#     REPO=owner/detect-lab ./run-attacks.sh            # safe phases only
#     REPO=owner/detect-lab ./run-attacks.sh --destroy  # also run destructive phases
#     ORG=my-lab-org REPO=my-lab-org/detect-lab ./run-attacks.sh
#
#  [LOGS?] tags show whether each phase produces a signal on a bare PERSONAL
#  account. git.clone/fetch and self-hosted runner events require an
#  organization / Enterprise Cloud.
# =============================================================================
set -uo pipefail

: "${REPO:?Set REPO=owner/repo}"
DESTROY="no"; [ "${1:-}" = "--destroy" ] && DESTROY="yes"
OWNER="${REPO%%/*}"

mark() { echo; echo "================================================================"; \
         echo ">>> PHASE $1 - $2   [$(date -u +%H:%M:%SZ)]"; echo \
         ">>> search your log in ~15 min for the events listed below"; \
         echo "================================================================"; }

# ----------------------------------------------------------------------------
mark 1 "CREDENTIAL SCANNING - commit a secret + bypass push protection"
echo "    emits: secret_scanning_push_protection.bypass, secret_scanning_alert.create   [LOGS: yes on public repo]"
# random, pattern-shaped but NON-FUNCTIONAL token -> reliably trips push protection
FAKE="ghp_$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)"
echo "leaked_github_token=$FAKE" > secrets/leaked-token.txt
git add secrets/leaked-token.txt
git commit -m "accidental token commit (lab)" || true
echo "    pushing... if push protection blocks it, re-run with the bypass reason:"
echo "    git push    (then choose 'used in tests' to emit the bypass event)"
git push || echo "    [!] blocked by push protection - bypass it in the UI to continue"

# ----------------------------------------------------------------------------
mark 2 "DATA EXFILTRATION - mass clone + flip repo to public"
echo "    emits: git.clone/git.fetch [LOGS: org/enterprise only], repo.access [LOGS: yes]"
mkdir -p /tmp/exfil
for r in $(gh repo list "$OWNER" --limit 50 --json nameWithOwner -q '.[].nameWithOwner' 2>/dev/null); do
  git clone "https://github.com/$r" "/tmp/exfil/$r" 2>/dev/null && echo "    cloned $r"
done
echo "    flipping $REPO to public (creates repo.access event)..."
gh repo edit "$REPO" --visibility public --accept-visibility-change-consequences 2>/dev/null \
  && echo "    [+] now public" || echo "    [!] skipped (already public or not permitted)"

# ----------------------------------------------------------------------------
mark 3 "CREDENTIAL ACCESS - add SSH key + mint a PAT"
echo "    emits: public_key.create [LOGS: yes], personal_access_token.* / oauth_*   [LOGS: yes]"
ssh-keygen -t ed25519 -f /tmp/lab_key -N "" -q <<<y >/dev/null 2>&1
gh ssh-key add /tmp/lab_key.pub --title "lab-persistence-$(date +%s)" 2>/dev/null \
  && echo "    [+] SSH key added (remember to delete it later)" \
  || echo "    [!] ssh-key add skipped"
echo "    PAT + OAuth grant: create in the UI (Settings > Developer settings)"
echo "        -> those also emit events you can detect."

# ----------------------------------------------------------------------------
mark 5 "CI/CD ABUSE - trigger the canary workflow"
echo "    emits: workflows.*, repo.actions_enabled   [LOGS: partial on personal]"
git commit --allow-empty -m "ci: trigger canary" && git push \
  && echo "    [+] push will run .github/workflows/lab-canary.yml" || true
echo "    self-hosted runner registration (org/enterprise) is the higher-signal variant."

# ----------------------------------------------------------------------------
if [ "$DESTROY" = "yes" ]; then
  mark 4 "REPO CHANGE - strip branch protection, force-push, DELETE repo (destructive)"
  echo "    emits: protected_branch.destroy, repo.destroy   [LOGS: yes]"
  gh api -X DELETE "repos/$REPO/branches/main/protection" 2>/dev/null \
    && echo "    [+] branch protection removed" || echo "    [!] no protection to remove"
  git commit --amend -m "tamper (lab)" --allow-empty && git push --force \
    && echo "    [+] force-pushed" || true
  echo "    deleting repo in 5s... Ctrl-C to abort"; sleep 5
  gh repo delete "$REPO" --yes && echo "    [+] repo deleted"
else
  echo; echo ">>> PHASE 4 (destructive: branch-protection teardown + delete) SKIPPED."
  echo ">>> re-run with --destroy to include it. Run it LAST - it removes the repo."
fi

echo; echo "[done] Now: find these events in your log, confirm they parse in SecOps,"
echo "       enable the rules in detections/github-rules.yaral, and tune."
