<p align="center">
  <img src="assets/images/icon.png" alt="Shark icon" width="128" height="128">
</p>

<h1 align="center">Shark</h1>

<p align="center">
  An artificial intelligence made with HaxeFlixel.
</p>

## About

Shark is a HaxeFlixel application that brings a conversational AI directly into a game engine environment. It combines a chat interface, AI-driven image generation, and mobile-ready UI into a single lightweight app, built entirely in Haxe.

The project is structured around a "brain" system (`Head`) that decides how to respond to user input — routing plain conversation through a chat backend, and image requests through a dedicated image generation pipeline — while keeping the UI, networking, and storage layers cleanly separated.

## Features

- **Chat interface** with a persistent conversation history, request queueing, and automatic retry with exponential backoff
- **AI image generation**, triggered either explicitly (`/image <description>`) or automatically when the AI embeds an image tag in its reply
- **Local image storage**, saving generated images as PNG files into a `content` folder in the app's storage
- **Online/offline detection**, with a live status indicator and automatic disabling of chat input when offline
- **Mobile-first UI**, with touch-friendly controls, adaptive sizing, and orientation handling
- **Aquatic visual theme**, with animated waves, light rays, kelp, and bubbles rendered entirely in HaxeFlixel
- **Cross-platform builds**: Windows, Android, iOS, and more via Lime/OpenFL

## Project Structure

```
Shark/
├── source/
│   ├── Main.hx                     Application entry point
│   ├── shark/
│   │   ├── active/
│   │   │   ├── PlayState.hx        Base gameplay/action state
│   │   │   └── system/
│   │   │       └── Head.hx         Core decision-making system ("the brain")
│   │   ├── backend/
│   │   │   └── Paths.hx            Asset path resolution and caching
│   │   ├── functions/
│   │   │   ├── ChatEngine.hx       AI chat requests, queueing, retries
│   │   │   └── ImageCreator.hx     AI image generation requests
│   │   ├── menus/
│   │   │   └── MainMenuState.hx    Main menu and chat UI
│   │   ├── mobile/
│   │   │   └── StorageUtil.hx      Saves generated images to local storage
│   │   ├── online/
│   │   │   └── Online.hx           Connectivity detection and monitoring
│   │   └── lime/
│   │       └── Build.hx            Programmatic build configuration
├── assets/
│   └── images/
│       └── icon.png                Application icon
├── Project.xml                     Lime/OpenFL project configuration
├── hmm.json                        Haxe dependency lockfile
└── .github/workflows/              CI build pipelines (Windows, Android)
```

## Requirements

- [Haxe](https://haxe.org/) 4.3.x
- [hmm](https://github.com/andywhite37/hmm) for dependency management
- [Lime](https://lime.software/) 8.3.2
- [HaxeFlixel](https://haxeflixel.com/) 5.9.0

## Installation

Clone the repository:

```bash
git clone https://github.com/Brenninho123/Shark.git
cd Shark
```

Install dependencies with `hmm`:

```bash
haxelib install hmm
haxelib run hmm install
```

Set up Lime for your target platform:

```bash
haxelib run lime setup -y
```

## Configuration

Shark connects to an external API for chat and image generation. Before running the app, configure the endpoints and credentials:

```haxe
shark.functions.ChatEngine.endpoint = "https://your-api-endpoint.com/chat";
shark.functions.ChatEngine.apiKey = "your-api-key";

shark.functions.ImageCreator.endpoint = "https://your-api-endpoint.com/image";
shark.functions.ImageCreator.apiKey = "your-api-key";
```

These are set once at startup, typically in `Main.hx`, before the game window is created.

## Building

**Windows:**

```bash
haxelib run lime build windows -final
```

**Android:**

```bash
haxelib run lime build android -final
```

CI builds for both targets run automatically via GitHub Actions (`.github/workflows/`).

## Usage

- Type a message and press **Enter** (desktop) or tap **Send** (mobile) to chat
- Type `/image <description>` to generate an image directly
- The AI can also embed image generation requests within its own replies
- Generated images are saved automatically to the `content` folder in the app's local storage

## License

This project is licensed under the Apache-2.0 License. See the [LICENSE](LICENSE) file for details.

## Author

Developed by Brenninho.
