<p align="center">
  <img src="arts/banner/image.png" alt="Shark banner" width="100%">
</p>

<h1 align="center">Shark</h1>

<p align="center">
  An artificial intelligence made with HaxeFlixel.
</p>

## About

Shark is a HaxeFlixel application that brings a conversational AI into a game engine environment. It combines a chat interface, AI-driven image generation, an animated avatar, a small collection of mini-games, a scriptable modding layer, and a fully mobile-ready UI — all built entirely in Haxe, with native C++ used where it genuinely helps.

The app is organized around a "brain and body" metaphor: `Head` decides how to respond to input (chat, commands, image requests), while `Body` is its animated on-screen avatar, reacting visually to what `Head` is doing. Everything else — networking, storage, audio, security, localization, performance, modding — is split into focused, independent systems.

## Features

- **Chat interface** with persistent history, request queueing, automatic retry, and a built-in command system (`/image`, `/help`, `/about`, `/status`, `/stats`, `/mute`, `/reset`, `/play`, `/language`)
- **AI image generation** with in-memory caching (LRU-capped), automatic local saving with prompt metadata, and magic-byte payload validation
- **An animated avatar (`Body`)** reacting to conversation state — idle, thinking, talking, reacting
- **Mini-games** (`!play`): Bubble Pop, Reef Runner, Deep Dive — keyboard, mouse, touch (tap/swipe/drag/long-press), and gamepad support
- **Full localization** (English, Portuguese, Spanish out of the box) with a compiled-in baseline and optional JSON overrides, in-chat language switching, and a language selector in Options
- **A modding system**: sandboxed `.hxs` (HScript) scripts loaded from a `mods/` folder, with lifecycle hooks (`onCreate`, `onUpdate`, `onDestroy`) and a curated, safe API surface
- **Advanced connectivity management**: adaptive polling, exponential backoff, jitter/stability tracking, connectivity event history, and an offline action queue with expiration
- **A security layer** (`Guard`): input sanitization, prompt-injection flagging, named rate-limit buckets, payload validation, URL allow-listing, safe filename checks, secure token generation
- **Structured crash logging** with deduplication and repeat-crash detection that triggers a safe mode
- **Runtime performance management**: adaptive render quality (with manual override), frame-time/memory monitoring, low-memory mode with automatic cache pruning, and device capability scoring
- **Native C++ utilities**: fast math, secure randomness, thread-safe counters, native boot checkpoints, CPU architecture/compiler detection
- **Persistent, externalized configuration** (`config.json`) covering network, chat, API parameters, image generation, audio, security, connectivity, and Discord presence — kept out of version control
- **Custom visuals**: an aquatic underwater shader (`water.frag`), procedural rounded rects/gradients/glow/soft-shadow textures, a custom cursor, and 4K display detection with UI scale calculation
- **Optional Discord Rich Presence** and experimental Nintendo Switch homebrew build support
- **Cross-platform builds**: Windows, Android, iOS, Linux, and macOS, all with automated, hardened CI

## Project Structure

```
Shark/
├── source/
│   ├── Main.hx                         Application entry point & lifecycle
│   ├── MainCpp.hx                      Native boot checkpoints (embedded C++)
│   ├── flixel/FlixelShark.hx           UI factories, transitions, particle fields
│   ├── git/
│   │   ├── graphic/GraphicGit.hx       Procedural textures (rounded rects, gradients, glow)
│   │   └── resolution/Resolution4K.hx  4K display detection & UI scale factor
│   ├── hscript/SharkScript.hx          Sandboxed hscript wrapper with rate limiting
│   ├── hxcpp/CPP.hx                    Native math, GC, memory, secure random, hashing
│   ├── lime/
│   │   ├── Build.hx, LimeShark.hx      Build config & unified native-systems facade
│   │   ├── crossplataform/             Per-platform build modules
│   │   ├── input/LimeInput.hx          Low-level window/keyboard access
│   │   ├── manager/                    LimeManager (performance), SutilLime (diagnostics)
│   │   └── sumil/LimeInternet.hx       Low-level socket reachability check
│   └── shark/
│       ├── active/
│       │   ├── GameState.hx            Mini-game selection screen
│       │   ├── games/                  BubblePopState, ReefRunnerState, DeepDiveState
│       │   └── system/                 Head (brain), Body + BodyState (avatar)
│       ├── audio/Audio.hx              Music/SFX, crossfade, mute, volume
│       ├── backend/
│       │   ├── Paths.hx                Asset resolution, caching, localization, ASTC prep
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
│       ├── modding/Module.hx           Loads and runs .hxs mod scripts
│       ├── online/                     Online, Network, Internet, User (anonymous ID)
│       ├── scripting/HScript.hx        App-bound scripting API (audio, body, stats)
│       ├── shaders/WaterShader.hx      Underwater distortion shader wrapper
│       └── ui/                         Input, Cursor, Guard, debug (DebugDisplay, CrasherLog), discord/Discord.hx
├── assets/
│   ├── images/                         icon.png, cursor/
│   ├── shaders/water.frag              Underwater distortion GLSL shader
│   └── data/                           config.json (gitignored), lang/
├── arts/banner/image.png               Repository banner
├── setup/application/Setup.hx          One-time project bootstrap (run outside source/)
├── project.hxp                         Lime/OpenFL project configuration (Haxe-based)
├── hmm.json                            Haxe dependency lockfile
└── .github/workflows/                  CI: Windows, Android, iOS, Linux, macOS, Switch (experimental)
```

## Requirements

- [Haxe](https://haxe.org/) 4.3.x
- [hmm](https://github.com/andywhite37/hmm) for dependency management
- [Lime](https://lime.software/) 8.3.2, [OpenFL](https://www.openfl.org/) 9.5.2, [hxp](https://github.com/openfl/hxp)
- [HaxeFlixel](https://haxeflixel.com/) 6.2.0, [flixel-addons](https://github.com/HaxeFlixel/flixel-addons) 4.0.1
- [flixel-ui](https://github.com/HaxeFlixel/flixel-ui) (git, tracks flixel compatibility)
- [hxcpp](https://github.com/HaxeFoundation/hxcpp) 4.3.2, [hscript](https://github.com/HaxeFoundation/hscript) 2.7.0
- [hxdiscord_rpc](https://github.com/MAJigsaw77/hxdiscord_rpc) 1.3.0 (optional, native targets only)

## Installation

```bash
git clone https://github.com/Brenninho123/Shark.git
cd Shark
haxelib install hmm
haxelib run hmm install
haxelib run lime setup -y
haxe --run setup/application/Setup.hx
```

The last step creates `assets/data/config.json` from a template, the required asset folders, and updates `.gitignore` — see [Configuration](#configuration).

## Configuration

Shark loads its configuration from `assets/data/config.json` at startup. This file is **gitignored** — `setup/application/Setup.hx` creates it from a template on first run. Fill in at least the `network` section before chatting:

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

Untrusted or malformed endpoint URLs are automatically blocked by `Guard`/`Main.setupSecurity()` before any request can be made. See the full template in `Setup.hx` for every available section (`chat`, `api`, `image`, `audio`, `security`, `connectivity`, `app`, `discord`).

## Building

```bash
haxelib run lime build windows -final
haxelib run lime build android -final
haxelib run lime build ios -simulator -final
haxelib run lime build linux -final
haxelib run lime build mac -final
```

All five targets build automatically via GitHub Actions on every push. Android release builds are signed with an auto-generated keystore in CI. A sixth, **experimental** Nintendo Switch homebrew workflow (`switch.yml`) is manual-only and not guaranteed to succeed — see the workflow file for details on that project's constraints.

## Usage

- Type a message and press **Enter** (desktop) or tap **Send** (mobile) to chat
- Built-in commands: `/image <description>`, `/help`, `/about`, `/status`, `/stats`, `/mute`, `/unmute`, `/reset`, `/play`, `/language <code>`
- The avatar reacts visually to sending, thinking, replying, and errors
- Chat history, generated images, and preferences persist automatically between sessions
- **F3** toggles a performance overlay (FPS, memory) in any build; it can also be turned on permanently from **Options**, where you can also change the language

## Modding

Drop a `.hxs` file (HScript) into the app's `mods/` folder to extend behavior without recompiling:

```haxe
function onCreate() {
	print("My mod loaded!");
}

function onUpdate(elapsed) {
	// runs every frame
}
```

Mods run in a sandbox (`SharkScript`/`Module`) with no file or network access unless explicitly exposed, and are rate-limited. See `sharmoddingng/Module.hx` and `shark/scripting/HScript.hx`.

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Author

Developed by Brenninho.
