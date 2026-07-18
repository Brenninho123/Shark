<p align="center">
  <img src="assets/images/icon.png" alt="Shark icon" width="128" height="128">
</p>

<h1 align="center">Shark</h1>

<p align="center">
  An artificial intelligence made with HaxeFlixel.
</p>

## About

Shark is a HaxeFlixel application that brings a conversational AI into a game engine environment. It combines a chat interface, AI-driven image generation, a small collection of mini-games, a scriptable behavior layer, and a fully mobile-ready UI — all built entirely in Haxe, with native C++ used where it genuinely helps.

The app is organized around a "brain and body" metaphor: `Head` decides how to respond to input (chat, commands, image requests), while `Body` is its animated on-screen avatar, reacting visually to what `Head` is doing. Everything else — networking, storage, audio, security, performance — is split into focused, independent systems.

## Features

- **Chat interface** with persistent history (saved to disk, restored on launch), request queueing, automatic retry, and a built-in command system (`/image`, `/help`, `/about`, `/status`, `/stats`, `/mute`, `/reset`, `/play`)
- **AI image generation**, with in-memory caching, automatic local saving (with prompt metadata), and magic-byte validation before decoding
- **An animated avatar (`Body`)** that reacts to conversation state — idle, thinking, talking, reacting
- **Mini-games**, reachable via `!play`: Bubble Pop, Reef Runner, Deep Dive — all with keyboard, mouse, touch, and gamepad support
- **A scripting layer** (`hscript`-based) with a sandboxed API for extending behavior without recompiling
- **Advanced connectivity management**: adaptive polling, exponential backoff, jitter/stability tracking, connectivity event history, and an offline action queue with expiration
- **A security layer** (`Guard`): input sanitization, prompt-injection flagging, rate limiting, payload validation, URL allow-listing, and safe filename checks
- **Structured crash logging** with deduplication and repeat-crash detection that triggers a safe mode
- **Runtime performance management**: adaptive render quality, frame-time/memory monitoring, and device capability scoring
- **Native C++ utilities**: fast math, secure randomness, thread-safe counters, native boot checkpoints
- **Persistent, externalized configuration** (`config.json`) covering network, chat, API parameters, image generation, audio, security, and connectivity — kept out of version control
- **Cross-platform builds**: Windows, Android, iOS, Linux, and macOS, all with automated, hardened CI

## Project Structure

```
Shark/
├── source/
│   ├── Main.hx                         Application entry point & lifecycle
│   ├── MainCpp.hx                      Native boot checkpoints (embedded C++)
│   ├── flixel/
│   │   └── FlixelShark.hx              UI factories, transitions, shared visual helpers
│   ├── hscript/
│   │   └── SharkScript.hx              Sandboxed hscript wrapper
│   ├── hxcpp/
│   │   └── CPP.hx                      Native math, GC, memory, secure random, hashing
│   ├── lime/
│   │   ├── Build.hx                    Programmatic build config (alt. to Project.xml)
│   │   ├── LimeShark.hx                Unified facade over Lime/native systems
│   │   ├── crossplataform/             Per-platform build modules
│   │   │   ├── Windows.hx / HTML5.hx / Linux.hx / Mac.hx
│   │   │   └── mobile/Android.hx / IOS.hx
│   │   ├── input/
│   │   │   └── LimeInput.hx            Low-level window/keyboard/soft-keyboard access
│   │   └── manager/
│   │       ├── LimeManager.hx          Platform detection & runtime performance
│   │       └── SutilLime.hx            Device capability scoring & diagnostics
│   └── shark/
│       ├── active/
│       │   ├── GameState.hx            Mini-game selection screen
│       │   ├── games/                  BubblePopState, ReefRunnerState, DeepDiveState
│       │   └── system/
│       │       ├── Head.hx             Decision-making & command system ("the brain")
│       │       ├── Body.hx             Animated avatar ("the body")
│       │       └── BodyState.hx
│       ├── audio/
│       │   └── Audio.hx                Music/SFX, crossfade, mute, volume
│       ├── backend/
│       │   ├── Paths.hx                Asset resolution, caching, localization
│       │   ├── JsonObject.hx           Type-safe JSON wrapper
│       │   ├── SharkCamera.hx          Camera effects & scene transitions
│       │   └── input/
│       │       └── Controls.hx         Unified keyboard/gamepad/touch for gameplay
│       ├── functions/
│       │   ├── ChatEngine.hx           Chat requests, queueing, persistence
│       │   └── ImageCreator.hx         Image generation, caching, auto-save
│       ├── menus/
│       │   ├── MainMenuState.hx        Main menu & chat UI
│       │   └── options/OptionsState.hx Settings screen
│       ├── mobile/
│       │   └── StorageUtil.hx          Mobile-only image storage with metadata & quotas
│       ├── online/
│       │   ├── Online.hx               Connectivity polling, jitter, event log
│       │   ├── Network.hx              Generic HTTP client (retry, timeout, cancel)
│       │   ├── NetworkResponse.hx
│       │   └── manager/Internet.hx     Connectivity management & offline queue
│       ├── scripting/
│       │   └── HScript.hx              App-bound scripting API (audio, body, stats)
│       └── ui/
│           ├── input/Input.hx          Chat-UI input helpers (pointer, swipe)
│           ├── input/Cursor.hx         Custom mouse cursor
│           ├── security/Guard.hx       Sanitization, rate limiting, validation
│           └── debug/
│               ├── DebugDisplay.hx     FPS/memory overlay (F3)
│               └── CrasherLog.hx       Structured crash logging
├── assets/
│   ├── images/                         icon.png, cursor/, etc.
│   └── data/                           config.json (gitignored), localization files
├── Project.xml                         Lime/OpenFL project configuration
├── hmm.json                            Haxe dependency lockfile
└── .github/workflows/                  CI: Windows, Android, iOS, Linux, macOS
```

## Requirements

- [Haxe](https://haxe.org/) 4.3.x
- [hmm](https://github.com/andywhite37/hmm) for dependency management
- [Lime](https://lime.software/) 8.3.2, [OpenFL](https://www.openfl.org/) 9.5.2
- [HaxeFlixel](https://haxeflixel.com/) 6.1.2, [flixel-addons](https://github.com/HaxeFlixel/flixel-addons) 4.0.1
- [flixel-ui](https://github.com/HaxeFlixel/flixel-ui) (git, tracks flixel compatibility)
- [hxcpp](https://github.com/HaxeFoundation/hxcpp) 4.3.2, [hscript](https://github.com/HaxeFoundation/hscript) 2.7.0

## Installation

```bash
git clone https://github.com/Brenninho123/Shark.git
cd Shark
haxelib install hmm
haxelib run hmm install
haxelib run lime setup -y
```

## Configuration

Shark loads its configuration from `assets/data/config.json` at startup (parsed by `Main.hx`, applied across `ChatEngine`, `ImageCreator`, `Audio`, `Guard`, `Online`, and `LimeManager`). This file is **not** committed — add it to `.gitignore` and create it locally:

```json
{
	"network": {
		"chatEndpoint": "https://your-api.com/chat",
		"chatApiKey": "your-key",
		"imageEndpoint": "https://your-api.com/image",
		"imageApiKey": "your-key",
		"requireOnline": true
	},
	"chat": { "systemPrompt": "...", "maxHistory": 40 },
	"api": { "chatModel": "", "chatTemperature": 0.8, "chatMaxTokens": 1024 },
	"image": { "cacheEnabled": true, "autoSaveToStorage": true },
	"audio": { "musicVolume": 0.5, "soundVolume": 0.7 },
	"security": { "maxRequestsPerWindow": 20 },
	"connectivity": { "onlineCheckInterval": 20 }
}
```

Untrusted or malformed endpoint URLs are automatically blocked by `Guard`/`Main.setupSecurity()` before any request can be made.

## Building

```bash
haxelib run lime build windows -final
haxelib run lime build android -final
haxelib run lime build ios -simulator -final
haxelib run lime build linux -final
haxelib run lime build mac -final
```

All five targets build automatically via GitHub Actions on every push. Android release builds are signed with an auto-generated keystore in CI.

## Usage

- Type a message and press **Enter** (desktop) or tap **Send** (mobile) to chat
- Built-in commands: `/image <description>`, `/help`, `/about`, `/status`, `/stats`, `/mute`, `/unmute`, `/reset`, `/play`
- The avatar reacts visually to sending, thinking, replying, and errors
- Chat history and generated images persist automatically between sessions
- **F3** toggles a performance overlay (FPS, memory) in any build; it can also be turned on permanently from **Options**

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Author

Developed by Brenninho.
