# As-Built Audit

## Audit 2026-10-10

### Scope and method

Audited the implementation at commit `c290407` against the conversation requirements and `PROJECT_DESIGN.md`. The configured `as-built-audit` skill was not present in the available skill catalog or filesystem, so this audit follows the workspace's stated read-only procedure directly. The implementation remained read-only during the audit; only this report was created.

### Result

Pass with one low-severity maintenance finding. No material gameplay, architecture, startup, content, security-advisory, or documentation defects were found.

### Findings

#### AUD-001 — GitHub Actions dependencies emit a Node.js deprecation annotation

- Severity: Low
- Status: Open
- Evidence: GitHub Actions run `38091147106` completed successfully, but reported that `actions/checkout@v4` and `actions/cache@v4` target deprecated Node.js 20 and were being forced to Node.js 24.
- Impact: CI currently passes, but future runner changes may turn the compatibility warning into a failure.
- Recommended correction: Upgrade the workflow actions to their then-current Node.js 24-compatible major releases and re-run CI.

### Requirement verification

- Five falling QuadBlock shapes support collision-aware movement, rotation, soft drop, hard drop, locking, line clears, and scoring.
- The ten-minute timer and per-second scoring continue on the topic screen while gravity pauses.
- Original supply-chain questions award points and randomized loot-box powerups; incorrect answers carry a score penalty.
- Random cyberattacks and licensing lawsuits expose educational text, deadlines, related-question remediation, Hotfix remediation, and real penalties: garbage rows, speed increase, rotation lock, or score drain.
- Garbage-row attacks can independently end a run by overflowing the board.
- Core rules reside in pure Elixir modules; LiveView owns scheduling, input mapping, and rendering only.
- Question and incident definitions are external JSON with load-time validation.
- README, MIT license, `.gitignore`, living design, and GitHub Actions workflow are present.
- The public GitHub repository exists at `https://github.com/pbleic/quadblockquiz` with `main` pushed.

### Verification evidence

- `mix format --check-formatted`: passed.
- `mix test`: 17 tests, 0 failures.
- `MIX_ENV=prod mix compile --warnings-as-errors`: passed for project code.
- `mix hex.audit`: no retired or advisory-bearing locked packages.
- `mix phx.server`: started successfully on Bandit; `/`, `/assets/app.js`, and `/assets/app.css` returned HTTP 200.
- Browser QA: LiveView connected without console warnings/errors; falling state advanced; topic screen opened; a quiz answer awarded 100 points and one loot-box item; desktop and mobile layouts rendered.
- GitHub Actions run `38091147106`: passed.

### Declared product limitations (not findings)

Anonymous single-player play is implemented. Account authentication, persistent leaderboards, real prize fulfillment, and multi-node session synchronization are explicitly outside this release's documented scope.
