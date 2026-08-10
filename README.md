<p align="center">
  <img src="arts/banners/image.png" alt="Shark banner" width="100%">
</p>

<h1 align="center">Shark</h1>

<p align="center">
  An artificial intelligence made with HaxeFlixel.
</p>

## About

Shark is a HaxeFlixel application that brings a conversational AI into a game engine environment. It combines a chat interface, AI-driven image generation, an animated avatar, a small collection of mini-games, a scriptable modding layer, achievements/leaderboards, and a fully mobile-ready UI — all built in Haxe, with native C++ used where it genuinely helps.

The app is organized around a "brain and body" metaphor: `Head` decides how to respond to input (chat, commands, image requests), while `Body` is its animated on-screen avatar, reacting visually to what `Head` is doing. Everything else — networking, storage, audio, security, localization, performance, modding, platform integrations — is split into focused, independent systems.

## Features

- **Chat interface** with persistent history, request queueing, automatic retry, and a built-in command system (`/image`, `/help`, `/about`, `/status`, `/stats`, `/mute`, `/reset`, `/play`, `/language`)
- **AI image generation** with in-memory LRU-capped caching, automatic local saving with prompt metadata, and magic-byte payload validation
- **An animated avatar (`Body`)** reacting to conversation state — idle, thinking, talking, reacting — with an optional path to full Adobe Animate sprite-based animation (`flxanimate`)
- **Mini-games** (`!play`): Bubble Pop, Reef Runner, Deep Dive — keyboard, mouse, touch (tap/swipe/drag/long-press), and gamepad support
- **Full localization** (English, Portuguese, Spanish out of the box) with a compiled-in baseline and optional JSON overrides, in-chat language switching, and a language selector in Options
- **A modding system**: sandboxed `.hxs` (HScript) scripts loaded from a `mods/` folder, with lifecycle hooks, a curated safe API, mod-provided asset overrides, and optional bundled "factory" mods shipped with the app
- **Advanced connectivity management**: adaptive polling, exponential backoff, jitter/stability tracking, connectivity event history, and a staggered offline action queue
- **A security layer** (`Guard`): input sanitization, prompt-injection flagging, named rate-limit buckets, payload validation, URL allow-listing, safe filename checks, secure token generation, path-traversal-safe file access (`FileSys`)
- **Structured, categorized crash logging** with deduplication, repeat-crash detection, and exportable reports
- **Runtime performance management**: adaptive render quality (with manual override and an explicit Boost mode), frame-time/memory monitoring, low-memory mode with automatic cache pruning, and device capability scoring
- **Native C++ utilities**: fast math, secure randomness, thread-safe counters, native boot checkpoints, CPU architecture/compiler detection, precise frame pacing
- **Persistent, externalized configuration** (`config.json`) covering network, chat, API parameters, image generation, audio, security, connectivity, and Discord presence — kept out of version control
- **Custom visuals**: an aquatic underwater shader (`water.frag`), procedural rounded rects/gradients/glow/soft-shadow textures, a custom cursor, dark-mode window theming (Windows), and 4K display detection with UI scale calculation
- **Platform integrations**: optional Discord Rich Presence, Newgrounds medals/scoreboards, Google Play Games achievements/leaderboards (Android), and experimental Nintendo Switch homebrew build support
- **HaxeUI support** alongside native Flixel UI, with an HScript-to-component binding layer
- **Branch-aware builds**: a `dev` branch mode (visible watermark, relaxed checks) and a `main` branch production mode (hard validation: config present, working tree clean, no merge-conflict markers, keystore present, etc.)
- **Cross-platform builds**: Windows, Android, iOS, Linux, macOS, and HTML5, all with automated, hardened CI

## Project Structure

```
Shark/
├── source/
│   ├── Main.hx                         Application entry point & lifecycle
│   ├── MainCpp.hx                      Native boot checkpoints (embedded C++)
│   ├── flixel/FlixelShark.hx           UI factories, transitions, particle fields, safety helpers
│   ├── git/
│   │   ├── graphic/GraphicGit.hx       Procedural textures (rounded rects, gradients, glow)
│   │   ├── performance/Boost.hx        Explicit performance boost (FPS target, GameMode on Linux)
│   │   └── resolution/Resolution4K.hx  4K display detection & UI scale factor
│   ├── haxe/ui/backend/HScriptManager.hx  Binds HaxeUI components to HScript
│   ├── hscript/SharkScript.hx          Sandboxed hscript wrapper with rate limiting
│   ├── hxcpp/CPP.hx                    Native math, GC, memory, secure random, hashing, timers
│   ├── lime/
│   │   ├── Build.hx, LimeShark.hx      Build config & unified native-systems facade
│   │   ├── crossplataform/             Per-platform build modules
│   │   ├── input/LimeInput.hx          Low-level window/keyboard access
│   │   ├── manager/                    LimeManager (performance), SutilLime (diagnostics)
│   │   └── sumil/LimeInternet.hx       Low-level socket reachability check
│   ├── macros/SharkMacro.hx            Compile-time build info (version, commit, platform)
│   └── shark/
│       ├── Assets.hx, FileSys.hx       Mod-aware asset resolution; safe file I/O
│       ├── active/
│       │   ├── GameState.hx            Mini-game selection screen
│       │   ├── games/                  BubblePopState, ReefRunnerState, DeepDiveState
│       │   └── system/                 Head (brain), Body + BodyState (avatar)
│       ├── api/                        google/GoogleClient.hx, newgrounds/NewClient.hx
│       ├── audio/                      Audio.hx, SoundGroup.hx (per-category volume/mute)
│       ├── backend/
│       │   ├── Paths.hx                Asset resolution, caching, localization, mod overrides
│       │   ├── JsonObject.hx           Type-safe JSON wrapper
│       │   ├── ClientPrefs.hx          Generic + named preference storage
│       │   ├── Language.hx             i18n: current language, translations, fallback
│       │   ├── language/               English/Portuguese/Spanish string tables
│       │   ├── SharkCamera.hx          Camera effects & scene transitions
│       │   └── input/Controls.hx       Unified keyboard/gamepad/touch/swipe for gameplay
│       ├── functions/                  ChatEngine.hx, ImageCreator.hx
│       ├── menus/                      MainMenuState.hx, options/OptionsState.hx
│       ├── mobile/
│       │   ├── StorageUtil.hx          Mobile-only image storage with metadata & quotas
│       │   └── utils/TouchUtil.hx      Multi-touch gestures: tap/double-tap/swipe/drag
│       ├── modding/                    Module.hx, ModuleHandler.hx (mod event bus)
│       ├── online/                     Online, Network, Internet, User (anonymous ID)
│       ├── scripting/HScript.hx        App-bound scripting API (audio, body, stats)
│       ├── shaders/WaterShader.hx      Underwater distortion shader wrapper
│       └── ui/                         Input, Cursor, Guard, window/WindowTheme.hx, debug (DebugDisplay, CrasherLog), discord/Discord.hx
├── assets/
│   ├── images/                         icon.png, cursor/
│   ├── shaders/water.frag              Underwater distortion GLSL shader
│   └── data/                           config.json (gitignored), lang/
├── mods/                               Optional bundled "factory" mods + README
├── arts/banners/image.png              Repository banner
├── setup/application/Setup.hx          One-time project bootstrap (dev branch only, run outside source/)
├── project.hxp                         Lime/OpenFL project configuration (Haxe-based, branch-aware)
├── Build.hxp                           Stricter CI/release build profile
├── hmm.json                            Haxe dependency lockfile
├── lime.bat                            Windows helper script (setup/build/release/publish/status/check)
├── VERSION, .build_number              Version tracking (build number auto-increments)
└── .github/workflows/                  CI: Windows, Android, iOS, Linux, macOS, HTML5, Switch (experimental)
```

## Requirements

- [Haxe](https://haxe.org/) 4.3.x
- [hmm](https://github.com/andywhite37/hmm) for dependency management
- [Lime](https://lime.software/) 8.3.2, [OpenFL](https://www.openfl.org/) 9.5.2, [hxp](https://github.com/openfl/hxp)
- [HaxeFlixel](https://haxeflixel.com/) 6.2.0, [flixel-addons](https://github.com/HaxeFlixel/flixel-addons) 4.0.1
- [flixel-ui](https://github.com/HaxeFlixel/flixel-ui) (git, tracks flixel compatibility)
- [hxcpp](https://github.com/HaxeFoundation/hxcpp) 4.3.2, [hscript](https://github.com/HaxeFoundation/hscript) 2.7.0, [SScript](https://github.com/EFC-team/SScript) 22.3.1
- Optional native integrations: `hxdiscord_rpc`, `hxvlc`, `hxWindowColorMode` (Windows), `hxgamemode` (Linux), `extension-androidtools` / `extension-googleplaygames` (Android), `newgrounds` (HTML5)
- `hxmath`, `haxeui-core` + `haxeui-flixel`, `polymod`, `flxanimate`

See `hmm.json` for the full, version-pinned dependency list.

## Installation

```bash
git clone https://github.com/Brenninho123/Shark.git
cd Shark
git checkout dev
haxelib install hmm
haxelib run hmm install
haxelib run lime setup -y
haxe --run setup/application/Setup.hx
```

`Setup.hx` refuses to run outside the `dev` branch (use `--force` to override). It creates `assets/data/config.json` from a template, the required asset folders, `mods/`, `VERSION`, and updates `.gitignore`.

On Windows, `lime.bat setup` does all of the above in one step, and `lime.bat status` / `lime.bat check` give a quick health check without a full build.

## Configuration

Shark loads its configuration from `assets/data/config.json` at startup. This file is **gitignored**. Fill in at least the `network` section:

```json
{
	"network": {
		"chatEndpoint": "https://your-api.com/chat",
		"chatApiKey": "your-key",
		"imageEndpoint": "https://your-api.com/image",
		"imageApiKey": "your-key"
	},
	"discord": { "enabled": false, "clientId": "" }
}
```

Untrusted or malformed endpoint URLs are automatically blocked by `Guard`/`Main.setupSecurity()` before any request can be made. See the full template in `Setup.hx` for every section (`chat`, `api`, `image`, `audio`, `security`, `connectivity`, `app`, `discord`).

## Building

```bash
haxelib run lime build windows -final
haxelib run lime build android -final
haxelib run lime build ios -simulator -final
haxelib run lime build linux -final
haxelib run lime build mac -final
haxelib run lime build html5 -final
```

All six targets build automatically via GitHub Actions on every push. Android release builds are signed with a keystore (path/password overridable via `SHARK_KEYSTORE_*` env vars). A seventh, **experimental** Nintendo Switch homebrew workflow (`switch.yml`) is manual-only and not guaranteed to succeed.

Two build profiles exist:
- **`project.hxp`** (default) — everyday development builds.
- **`Build.hxp`** — a stricter, CI-style profile. Run it with `haxelib run lime build Build.hxp <target> -final`, or `lime.bat release <target>`.

On the **`main`** branch, `project.hxp` runs a production checklist before building (config present, VERSION valid, working tree clean, no leftover merge-conflict markers, Android keystore present, VERSION tagged in git, `CHANGELOG.md` mentions the version) and **blocks the build** if a required item fails. `lime.bat publish <target>` only runs from `main`. On the **`dev`** branch, builds get a visible "Dev Build (Commit: ...)" watermark instead.

---

# Using the AI

This section covers everything you can do once the app is running and `config.json` points at a working chat/image backend.

## Talking to Shark

Type a message in the input box and press **Enter** (desktop) or tap the send button (mobile). Shark replies in the same window, and the avatar (`Body`) reacts visually:

| Avatar state | When it happens |
|---|---|
| Idle | Default — slow breathing pulse |
| Thinking | While waiting for a reply — faster pulse, lighter color |
| Talking | Right after you send a message |
| Reacting | When a reply or image comes back — a quick elastic "pop" |

Conversation history is saved automatically to disk and restored the next time you open the app. If the chat backend isn't configured yet, Shark tells you so directly instead of pretending to respond.

## Built-in commands

Type any of these in the chat box, with or without a leading `/` or `!` (both work):

| Command | What it does |
|---|---|
| `/image <description>` | Generates an image from a text description and displays it in the chat window. Cached, so asking for the same prompt twice is instant the second time. |
| `/reset` or `/clear` | Clears the conversation and starts fresh with a new greeting. |
| `/help` | Lists all available commands. |
| `/about` | A short description of what Shark is. |
| `/status` | Shows connection status and whether the chat backend is configured. |
| `/stats` | Shows how many messages/images have been exchanged, plus session info (launch count, session duration). |
| `/mute` / `/unmute` | Toggles all sound. |
| `/play` | Opens the mini-game selection screen. Works even while chatting mid-conversation. |
| `/language <code>` | Switches Shark's language on the fly (`en`, `pt`, `es`). Leave the code off to see the list of supported ones. |

Commands never leave the local sandbox — they're handled entirely by `Head.hx` before anything is sent to the network, except `/image` and normal chat messages, which do call your configured API.

## Generating images

`/image a shark wearing sunglasses, cartoon style` sends the prompt to your configured `imageEndpoint`. The result is:

- Displayed inline in the chat
- Cached in memory (an LRU cache, default 30 entries) so repeat prompts don't re-download
- Automatically saved to device storage on mobile, with the prompt kept as metadata so you can search for it later (`findByPrompt()` in `StorageUtil`)
- Validated against real PNG/JPEG magic bytes before decoding, so a malformed or malicious response can't be rendered as-is

## Settings (Options screen)

Open **Options** from the main menu (or the icon-button row) to:

- Toggle the **FPS/memory overlay** permanently (same overlay F3 toggles temporarily in any build)
- Change the **language** (cycles through installed languages; also settable from chat via `/language`)

More options (per-category volume via `SoundGroup`, a performance mode selector for `Boost`) can be wired in as the Options screen grows — the underlying systems already support them.

## Mini-games

Reach the mini-game menu any time with `/play` or `!play`. Three games are included:

- **Bubble Pop** — pop rising bubbles before they escape (60s timer)
- **Reef Runner** — endless runner, jump to dodge obstacles
- **Deep Dive** — dodge falling rocks while diving deeper

All three support keyboard, mouse, touch (including swipe-as-direction on mobile), and gamepad. If configured, scores can be posted to **Newgrounds** scoreboards (web) or **Google Play Games** leaderboards (Android), and achievements can unlock through the same integrations.

## Modding

Drop a `.hxs` file (HScript) into the app's `mods/` folder to extend behavior without recompiling. On mobile/desktop this is a real folder on disk (inside the app's private storage); the app also ships with the ability to bundle "factory" mods that get copied there automatically on first run if you place a `mods/` folder at the repo root before building.

```haxe
function onCreate() {
	print("My mod loaded!");
}

function onUpdate(elapsed) {
	// runs every frame
}

function onMessageSent(message) {
	print("You said: " + message);
}

function onReplyReceived(reply) {
	bodyReact();
}
```

Available inside every mod script by default: `print()`, `Math`, `Std`, `StringTools`, `playSound(key)`, `muteAudio()` / `unmuteAudio()`, `bodyIdle()` / `bodyThink()` / `bodyTalk()` / `bodyReact()` / `bodyBlink()`, `getMessageCount()`, `getImageCount()`, plus app-wide event hooks (`onThinkingStart`/`onThinkingEnd`, `onFlaggedInput`, `onRateLimited`, `onNavigate`, `onMessageSent`, `onReplyReceived`, `onImageGenerated`, `onError`, `onStateChanged`, `onLanguageChanged`).

Mods run in a sandbox (`SharkScript` → `Module` → `Mods` → `ModuleHandler`) with:
- **No file or network access** unless explicitly exposed
- **Rate limiting** on script execution (a dedicated bucket, separate from chat's)
- **Slow-execution logging** — any script run taking longer than the threshold gets logged
- Mods can also **override assets** — dropping a same-named file under `<mods folder>/assets/images/` or `assets/data/` replaces the built-in one at runtime

A mod can be reloaded live via `Mods.reloadModule(name)`, or all at once with `Mods.reloadAll()` — no restart required.

## Diagnostics

- **F3** — toggles the FPS/memory overlay in any build
- `SutilLime.getDiagnosticsReport()` — platform, build, device score, frame timing, memory, native build info (version/commit/arch/compiler), boot checkpoints
- `CrasherLog.exportReport()` — writes a categorized crash/warning report to disk for bug reports
- `Network.getStatsSummary()` / `Internet.getDetailedStatus()` — network health at a glance

---

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Author

Developed by Brenninho.
