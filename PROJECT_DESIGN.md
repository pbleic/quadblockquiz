# Quadblockquiz Project Design

## Purpose

Quadblockquiz is a browser-based educational tetrominoes game about software supply-chain security. Players stack five kinds of QuadBlocks, pause falling to answer original quiz questions, open earned loot boxes for powerups, and respond to cyberattacks or licensing lawsuits before penalties take effect.

## Architecture

- `Quadblockquiz.Game` is the pure state machine for clocks, scoring, input, quiz rewards, events, and game-over rules.
- `Quadblockquiz.Game.Board` owns collision, locking, row clearing, and garbage-row penalties.
- `Quadblockquiz.Game.Piece` defines the five QuadBlock shapes and rotations.
- `Quadblockquiz.Content` loads and validates extensible JSON definitions from `priv/content`.
- `QuadblockquizWeb.GameLive` owns the browser timer and renders state. It contains no game rules.

Random selection uses an explicit Erlang RNG state stored inside the game state. Given the same seed and actions, the engine produces the same result. No database or user account is required for this initial anonymous-play release.

## Rules and terminology

- The board is 10 columns by 20 rows. Five shapes are available: Bar, Box, Tee, Boot, and Zig.
- A point is earned for every elapsed second, including while the topic screen is open. Row clears and correct quiz answers add points.
- Space opens the topic screen and stops only gravity. The ten-minute clock and vulnerability deadlines continue.
- Correct answers award a loot box containing one powerup: Row Blast, Slow Clock, or Hotfix.
- Random cyberattack and licensing-lawsuit events begin after 30 seconds and recur after resolution. Ignoring an event until its deadline applies its specified penalty.
- The game ends when a new QuadBlock cannot spawn, the player quits, or ten minutes elapse. Ignored incidents remain active and can indirectly end the run through board pressure.

## Data and extension points

Questions and vulnerability definitions live in JSON under `priv/content`. New content does not require engine changes as long as it uses an existing penalty or powerup identifier. New mechanics require a deliberately tested engine branch.

## Verification

Core rules are covered with ExUnit unit tests. LiveView integration tests verify initial rendering and key flows. CI runs `mix format --check-formatted` and `mix test`.
