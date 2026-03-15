# WorkspaceSwitcher

A lightweight macOS menu bar app that lets you switch between multiple **Claude Code** and **GitHub** accounts with a single click.

Organize your accounts into workspaces (e.g., "Work", "Personal") and switch all credentials at once — no more manual `gh auth switch` or keychain juggling.

## Features

- **One-click workspace switching** from the macOS menu bar
- **Claude Code** account management via Keychain
- **GitHub CLI** (`gh`) account switching with device code auth flow
- **Multiple workspaces** with custom icons (SF Symbols or emoji)
- **Launch at login** support
- Native macOS app — lightweight, no Electron, no background processes

## How It Works

```
┌─────────────────────────────────┐
│  Menu Bar                       │
│  ┌───┐                          │
│  │ 💼│ ← Click workspace icon   │
│  └───┘                          │
│  ┌─────────────────────┐        │
│  │ ✓ Work         💼   │        │
│  │   Personal     🏠   │        │
│  │ ──────────────────  │        │
│  │   Settings…     ⌘,  │        │
│  │   Quit          ⌘Q  │        │
│  └─────────────────────┘        │
└─────────────────────────────────┘
```

1. **Create workspaces** in Settings (e.g., "Work", "Personal")
2. **Add accounts** to each workspace via the built-in login flow
3. **Click a workspace** in the menu bar to switch all accounts at once

When you switch workspaces, WorkspaceSwitcher:
- Writes the correct Claude Code OAuth token to your Keychain
- Runs `gh auth switch` to activate the right GitHub account

## Installation

### Download (Recommended)

1. Go to [**Releases**](../../releases)
2. Download the latest `WorkspaceSwitcher-x.x.x.dmg`
3. Open the DMG and drag **WorkspaceSwitcher** to your Applications folder
4. Launch the app — it will appear in your menu bar

> **Note:** On first launch, macOS may show a warning since the app is not notarized.
> Go to **System Settings → Privacy & Security** and click **"Open Anyway"**.

### Build from Source

**Requirements:** Xcode 15+ and macOS 13 (Ventura) or later.

```bash
git clone https://github.com/marianochavez/workspace_switcher.git
cd workspace_switcher

# Build and run in Xcode
open WorkspaceSwitcher.xcodeproj
# Then press Cmd+R

# Or build the DMG directly
bash scripts/build-dmg.sh
open build/WorkspaceSwitcher.dmg
```

## Prerequisites

The app manages credentials for these CLI tools — install the ones you need:

| Tool | Install | Purpose |
|------|---------|---------|
| [GitHub CLI](https://cli.github.com) | `brew install gh` | GitHub account switching |
| [Claude Code](https://claude.ai/code) | `npm install -g @anthropic-ai/claude-code` | Claude Code account switching |

## Setup Guide

### 1. Open Settings

Click the menu bar icon → **Settings…** (or `Cmd + ,`)

### 2. Create a Workspace

Click the **+** button in the sidebar. Give it a name and pick an icon.

### 3. Add Accounts

In the workspace detail view, use the **Add Accounts** section:

- **GitHub** — Starts `gh auth login` with device code flow. The app shows your one-time code, copies it to clipboard, and opens GitHub in your browser.
- **Claude Code** — Starts `claude auth login`. Complete the OAuth flow in your browser.

### 4. Switch Workspaces

Click any workspace in the menu bar dropdown. All associated accounts switch instantly.

## Project Structure

```
WorkspaceSwitcher/
├── App/                    # Entry point, AppDelegate
├── Models/                 # Workspace, Account, WorkspaceStore
├── Services/               # ClaudeCodeSwitcher, GitHubSwitcher, Shell
├── UI/                     # SwiftUI Settings, AppKit StatusBar/Menu
└── Resources/              # Assets, Info.plist
```

## Development

```bash
# Run tests
xcodebuild test \
  -project WorkspaceSwitcher.xcodeproj \
  -scheme WorkspaceSwitcher \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-"

# Generate app icon (all sizes)
swift scripts/generate-icon.swift

# Build DMG
bash scripts/build-dmg.sh
```

## Creating a Release

Tag a version to trigger the automated release workflow:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This runs tests, builds the DMG, and creates a GitHub Release with the installer attached.

## License

MIT
