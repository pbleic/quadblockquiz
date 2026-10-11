# Quadblockquiz Project Design

## Purpose

Quadblockquiz is a browser-based educational tetrominoes game about software supply-chain security. Players stack five kinds of QuadBlocks, pause falling to answer original quiz questions, open earned loot boxes for powerups, and respond to cyberattacks or licensing lawsuits before penalties take effect.

## Architecture

- `Quadblockquiz.Game` is the pure state machine for clocks, scoring, input, quiz rewards, events, and game-over rules.
- `Quadblockquiz.Game.Board` owns collision, locking, row clearing, and garbage-row penalties.
- `Quadblockquiz.Game.Piece` defines the five QuadBlock shapes and rotations.
- `Quadblockquiz.Content` loads and validates extensible JSON definitions from `priv/content`.
- `QuadblockquizWeb.GameLive` owns the browser timer and renders state. It contains no game rules.

The interface uses readable laptop-scale typography and a height-aware desktop layout. On viewports 1200 pixels tall or shorter, including common fullscreen displays, nonessential header copy is hidden and the board scales to keep the complete game shell on screen at 100% browser zoom. The `F` key requests browser fullscreen, with `Esc` returning to windowed mode.

`bin/start` is the supported local launcher. It prefers the known-compatible Elixir 1.20/OTP 27 installation when available and isolates Mix, Hex, Rebar, dependencies, and build products beneath the repository's ignored `.local` directory. This prevents global-tool and stale-build mismatches from affecting startup.

Random selection uses an explicit Erlang RNG state stored inside the game state. LiveView supplies a fresh cryptographic seed for every new or restarted game, while tests provide a fixed seed so transitions remain reproducible. The piece picker excludes the current preview piece from the next draw to prevent immediate duplicates. No database or user account is required for this initial anonymous-play release.

Quiz selection uses a shuffled deck per topic or active incident. A correctly answered question is not repeated until the applicable deck is exhausted. A missed or skipped question is placed at the back of the current deck so it returns after other material. Deck state lasts for the current browser game only.

## Rules and terminology

- The board is 10 columns by 20 rows. Five shapes are available: Bar, Box, Tee, Boot, and Zig.
- A point is earned for every elapsed second, including while the topic screen is open. Row clears and correct quiz answers add points.
- Space opens the topic screen and stops only gravity. The ten-minute clock and vulnerability deadlines continue.
- Correct answers award a loot box containing one powerup: Row Blast, Slow Clock, or Hotfix.
- During an active incident, pressing Space bypasses topic selection and opens an incident-related question directly; a correct response reliably resolves the incident. Without an incident, the topic menu remains available for optional study. Answering any question automatically resumes play. Spending one stored Hotfix bypasses the question and resolves an incident immediately.
- Question choices wrap within the overlay and support both pointer input and keyboard selection: Up/Down changes the highlighted answer and Enter submits it.
- Random cyberattack and licensing-lawsuit events begin after 30 seconds and recur after resolution. Ignoring an event until its deadline applies its specified penalty.
- Left/right movement and quarter-turn rotation remain available throughout play. Rotation uses small horizontal and upward boundary kicks so valid turns continue near walls and the floor.
- The game ends when a new QuadBlock cannot spawn, the player quits, or ten minutes elapse. Ignored incidents remain active and can indirectly end the run through board pressure.

## Data and extension points

Questions and vulnerability definitions live in JSON under `priv/content`. The base question file and categorized files under `priv/content/questions/` form one validated bank. New content does not require engine changes as long as it uses an existing vulnerability identifier. New mechanics require a deliberately tested engine branch. `docs/DATABASE_DECISION.md` records the reasons for remaining file-based and the requirements that would trigger database adoption.

## Verification

Core rules are covered with ExUnit unit tests. LiveView integration tests verify initial rendering and key flows. CI runs `mix format --check-formatted` and `mix test`.
