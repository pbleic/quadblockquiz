# Database Decision: Question and Game Data

## Current decision

Quadblockquiz does **not** need a database for its current anonymous, single-node release. Quiz questions and vulnerability definitions are versioned JSON content, loaded into memory when a game starts. This keeps local startup simple, makes content changes reviewable in Git, requires no database service or migrations, and easily supports hundreds or thousands of questions.

The question-selection engine keeps each player's shuffled deck in the LiveView game state. That is sufficient while a game exists only for the lifetime of one browser connection and no long-term player history is promised.

## Reasons to introduce a database

A database becomes worthwhile when one or more of these product requirements is approved:

1. **Persistent player progress** — remember answered, mastered, or missed questions across browser sessions and devices.
2. **Accounts and authentication** — associate scores, inventory, achievements, contest eligibility, or handles with GitHub/email identities.
3. **Leaderboards and prizes** — retain auditable scores, game results, contest periods, and prize fulfillment records.
4. **A content-management interface** — let authorized editors create, review, publish, retire, tag, or correct questions without changing and deploying repository files.
5. **Community-authored content** — support submissions, moderation, attribution, voting, reporting, and revision history.
6. **Analytics and adaptive learning** — measure question difficulty, distractor effectiveness, incident-response success, or select questions based on a player's demonstrated knowledge.
7. **Live content updates** — publish question changes without restarting application nodes or deploying a new release.
8. **Multiple application nodes** — coordinate persistent sessions, shared leaderboards, or content versions across a cluster.
9. **Localization and variants** — manage translations, regional licensing content, difficulty levels, and question-version relationships at scale.
10. **Compliance and audit requirements** — retain consent, contest actions, score provenance, administrative changes, or deletion records.

## Data that would belong in the database

If those needs arise, the likely schema boundaries are:

- `users` and authentication identities
- `games`, scores, end reasons, and timestamps
- `questions`, choices, explanations, topics, difficulty, status, and content version
- `vulnerabilities` and their question relationships
- `question_attempts` with correctness and response timing
- `inventory_events` and powerup usage
- `content_revisions` and editor/auditor identity
- contest, leaderboard, and prize records if those features are added

The falling-piece board and tick-by-tick game state should generally remain in memory rather than generating a database write on every game tick. Save only meaningful checkpoints or completed-game summaries unless reconnection/resume requirements demand more.

## Recommended migration path

When a trigger above is approved:

1. Add Ecto and PostgreSQL through the standard Phoenix repository pattern.
2. Preserve stable question and vulnerability IDs from the JSON files.
3. Import the versioned JSON bank through an idempotent seed task.
4. Keep gameplay modules pure by passing loaded question data into `Quadblockquiz.Game`; do not put database calls inside the game engine.
5. Put persistence and content queries behind a separate context module.
6. Add migrations, constraints, indexes, backup procedures, and authorization tests before enabling editor or contest features.

## Review checkpoint

Revisit this decision before implementing authentication, persistent progress, leaderboards/prizes, content editing, adaptive learning, or multi-node deployment. Until then, a database would add installation and operational complexity without improving the current gameplay experience.
