# GitHub Detection Lab

A self-contained lab to **simulate five GitHub attacks on a repo you own**, capture
the resulting logs, and validate detections in Google SecOps (YARA-L).

> **Scope & safety.** Run only against your own account/repos. Every "secret" here is
> a fake, non-functional placeholder. The runner generates random pattern-shaped
> tokens that authenticate to nothing. Revoke any SSH key / PAT / OAuth grant you
> create, and keep the destructive phase for a throwaway repo.

## The honest part: what logs where

| Your tier | Audit source | `git.clone/fetch` | Native streaming |
|---|---|---|---|
| Personal account | Settings → Security log (UI; no clean API) | no | no |
| Free organization | `GET /orgs/{org}/audit-log` (API) | no | no |
| Enterprise Cloud | full audit log | **yes** | **yes** (S3/GCS → SecOps) |

**Recommendation:** for clean detection, run the lab inside a **free org** and capture
with `collect/pull-audit-log.sh` (org JSON parses cleanly as log type `GITHUB`).
On a bare personal account, use `collect/forward-webhooks.py` and detect against a
**custom** log type — webhook JSON is a different schema from the audit log.

## Layout

```
secrets/      fake credentials (static, well-known non-functional values)
src/          decoy source so clone/exfil has realistic volume
.github/      canary workflow (echoes a fake value only)
collect/      log capture: org audit-log puller + personal webhook forwarder
detections/   the 5 YARA-L rules, ready to import
seed-lab.sh   commit & push the test files
run-attacks.sh  run the 5 simulations, phase-marked with timestamps
```

## Run it

```bash
# 0. create a throwaway repo and clone it, then drop these files in
gh repo create YOURNAME/detect-lab --private --clone
cd detect-lab && cp -r /path/to/github-detect-lab/* .

# 1. seed the test files
REPO=YOURNAME/detect-lab ./seed-lab.sh

# 2. start capturing (pick one)
ORG=my-lab-org SECOPS_INGEST_URL=... SECOPS_TOKEN=... ./collect/pull-audit-log.sh   # org
#   or
python3 collect/forward-webhooks.py                                                 # personal

# 3. run the attacks (safe phases)
REPO=YOURNAME/detect-lab ./run-attacks.sh
#   include the destructive phase (branch-protection teardown + repo delete):
REPO=YOURNAME/detect-lab ./run-attacks.sh --destroy

# 4. in SecOps: confirm events parse, import detections/github-rules.yaral, tune
```

## The five attacks

1. **Credential scanning** — commit a secret, bypass push protection
2. **Data exfiltration** — mass clone + flip a repo to public
3. **Credential access** — add SSH key, mint PAT, authorize OAuth app
4. **Repo change** — remove branch protection, force-push, delete repo *(destructive)*
5. **CI/CD abuse** — canary workflow / self-hosted runner

Each maps to named audit events and a YARA-L rule in `detections/`. Verify field
paths in the UDM viewer before trusting a rule in production.
