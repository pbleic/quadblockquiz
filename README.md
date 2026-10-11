# Quadblockquiz — Supply Chain Edition

Quadblockquiz is a playable Phoenix LiveView game that combines falling QuadBlocks with original software supply-chain trivia. Stack the five four-square shapes, clear rows, answer questions to earn loot-box powerups, and respond to cyberattacks and licensing lawsuits before their penalties land.

The gameplay terminology and high-level feel are based on the public [Quizquadaminos player guide](https://github.com/sparrell/quizquadaminos/blob/develop/docs/HowToPlay.md). This repository contains an original Elixir implementation and original quiz content; no source code was copied from Quizquadaminos.

## Run locally

Requirements:

- Elixir 1.16 or newer with Erlang/OTP
- Internet access the first time Hex dependencies are downloaded

```bash
git clone https://github.com/pbleic/quadblockquiz.git
cd quadblockquiz
mix deps.get
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000). No database setup is needed.

For development setup and verification:

```bash
mix setup
mix format --check-formatted
mix test
```

## How to play

- `←` and `→` move the falling QuadBlock.
- `↑` rotates it; `↓` soft-drops it; `Enter` hard-drops it.
- `Space` opens the topic screen. Gravity pauses there, but the game clock and incident deadlines keep running.
- Clearing rows scores 100/300/500/800 points for one through four rows. Every elapsed second scores one point, and a correct answer scores 100.
- Correct answers open a loot box containing **Row Blast**, **Slow Clock**, or **Hotfix**.
- A related correct answer or a Hotfix resolves the active cyberattack or licensing lawsuit. If its deadline expires, the event adds risk rows, accelerates falling, or drains score. Core movement and rotation controls always remain available when the piece has room.
- The run ends when the stack blocks a new QuadBlock, you quit from the topic screen, or ten minutes expire.

Alternating between block play and questions is the intended strategy: quizzes fund the powerups that make later incidents and faster levels manageable.

## Content and architecture

Original questions are in [`priv/content/questions.json`](priv/content/questions.json), and incident definitions are in [`priv/content/vulnerabilities.json`](priv/content/vulnerabilities.json). Add entries there without changing game rules. Content is validated when a game starts.

All gameplay rules are isolated from LiveView in `lib/quadblockquiz/game.ex` and `lib/quadblockquiz/game/`. Randomness is explicit state, so seeded games are repeatable in tests. `QuadblockquizWeb.GameLive` only schedules ticks, maps input to engine calls, and renders the result. See [`PROJECT_DESIGN.md`](PROJECT_DESIGN.md) for the living design.

The browser bundle is checked in so normal startup needs no Node toolchain. After changing files under `assets/`, rebuild it from that directory with:

```bash
NODE_PATH=../deps npx esbuild@0.25.10 js/app.js --bundle --target=es2017 \
  --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --minify
```

## Current scope

This release supports anonymous, single-player browser sessions. It does not yet persist scores, authenticate players, award real contest prizes, or synchronize games across nodes.

## License

MIT
