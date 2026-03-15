<div align="center">

# WorkspaceSwitcher

### Switch between Claude Code & GitHub accounts from your macOS menu bar

[![Version](https://img.shields.io/github/v/release/marianochavez/workspace_switcher?label=version&color=blue)](https://github.com/marianochavez/workspace_switcher/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com/marianochavez/workspace_switcher/releases)
[![Built with Swift](https://img.shields.io/badge/built%20with-Swift%20%7C%20SwiftUI-orange.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/github/license/marianochavez/workspace_switcher)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/marianochavez/workspace_switcher/ci.yml?label=CI)](https://github.com/marianochavez/workspace_switcher/actions/workflows/ci.yml)

</div>

## Why WorkspaceSwitcher?

Working with multiple Claude Code and GitHub accounts means constantly running `gh auth switch`, editing Keychain entries, and remembering which credentials go together. WorkspaceSwitcher groups your accounts into **workspaces** and switches them all with a single click from the menu bar.

- **One click, all accounts switch** — Claude Code + GitHub credentials swap together
- **Native macOS menu bar app** — lightweight, no Electron, no background daemons
- **Built-in auth flows** — GitHub device code and Claude OAuth login without leaving the app
- **Custom icons** — monochrome SF Symbols for the menu bar or colorful emoji

## How It Works

```
  ┌───┐
  │ 💼│  ← menu bar icon
  └─┬─┘
    │
  ┌─▼───────────────────┐
  │ ✓ Work          💼  │  ← active workspace
  │   Personal      🏠  │
  │ ─────────────────── │
  │   Settings…     ⌘,  │
  │   Quit          ⌘Q  │
  └─────────────────────┘
```

| Step | Action |
|------|--------|
| **1. Create** | Open Settings → add a workspace → pick a name and icon |
| **2. Link** | Click **GitHub** or **Claude Code** login → authenticate in your browser |
| **3. Switch** | Click any workspace in the menu bar → all accounts switch instantly |

**Under the hood**, switching a workspace:
- Writes the matching Claude Code OAuth token into your macOS Keychain
- Runs `gh auth switch --user <username>` to activate the correct GitHub account

## Installation

### Download

> [![Download DMG](https://img.shields.io/github/v/release/marianochavez/workspace_switcher?label=Download%20DMG&color=success&style=for-the-badge)](https://github.com/marianochavez/workspace_switcher/releases/latest)

1. Download the latest **WorkspaceSwitcher-x.x.x.dmg** from [Releases](https://github.com/marianochavez/workspace_switcher/releases/latest)
2. Open the DMG and drag **WorkspaceSwitcher** into `/Applications`
3. Launch the app — it appears in the menu bar (no Dock icon)

<details>
<summary><strong>macOS shows "unidentified developer" — how do I fix it?</strong></summary>

The app is ad-hoc signed (no Apple Developer certificate). On first launch:

1. Close the warning dialog
2. Go to **System Settings → Privacy & Security**
3. Click **"Open Anyway"**

After that, the app opens normally.
</details>

### Build from Source

**Requirements:** [Xcode](https://developer.apple.com/xcode/) 15+ · macOS 13 (Ventura) or later

```bash
git clone https://github.com/marianochavez/workspace_switcher.git
cd workspace_switcher

# Option A: Open in Xcode and press Cmd+R
open WorkspaceSwitcher.xcodeproj

# Option B: Build the DMG installer
bash scripts/build-dmg.sh
open build/WorkspaceSwitcher.dmg
```

## Prerequisites

WorkspaceSwitcher manages credentials for these CLI tools. Install the ones you use:

| Tool | Install | Used for |
|------|---------|----------|
| [GitHub CLI](https://cli.github.com) | `brew install gh` | Switching GitHub accounts |
| [Claude Code](https://claude.ai/code) | `npm install -g @anthropic-ai/claude-code` | Switching Claude Code accounts |

> Both tools must be authenticated at least once before WorkspaceSwitcher can manage them.

## Getting Started

### 1. Open Settings

Click the menu bar icon → **Settings…** (or <kbd>Cmd</kbd> + <kbd>,</kbd>)

### 2. Create a Workspace

Click **+** in the sidebar. Give it a name and choose an icon:
- **Menu Bar** tab — monochrome SF Symbols (look native in the macOS status bar)
- **Custom** tab — colorful emoji

### 3. Add Accounts

Use the **Add Accounts** cards in the workspace detail view:

| Provider | Auth Flow |
|----------|-----------|
| **GitHub** | Runs `gh auth login`. The app captures the device code, copies it to your clipboard, and opens GitHub in the browser. |
| **Claude Code** | Runs `claude auth login`. Complete the OAuth flow in your browser. |

The app automatically detects which account was just authenticated and adds it to the workspace.

### 4. Switch

Click any workspace name in the menu bar dropdown. Done.

## Architecture

```
WorkspaceSwitcher/
├── App/                # main.swift, AppDelegate
├── Models/             # Workspace, Account, WorkspaceStore (ObservableObject)
├── Services/
│   ├── ClaudeCodeSwitcher  # Keychain read/write via /usr/bin/security
│   ├── GitHubSwitcher      # gh auth status/switch/login
│   ├── SwitcherService     # Orchestrates multi-account switching
│   ├── KeychainService     # SecItem wrapper
│   └── Shell               # Process launcher with login-shell PATH support
├── UI/
│   ├── StatusBarController  # NSStatusItem (AppKit)
│   ├── MenuBuilder          # Dynamic menu construction (AppKit)
│   ├── SettingsWindowController  # NSWindow shell (AppKit)
│   └── SettingsContentView      # Full settings UI (SwiftUI)
└── Resources/          # Assets.xcassets, Info.plist
```

> **Design:** The menu bar and window shell use AppKit; all settings content is SwiftUI via `NSHostingView`.

## Development

```bash
# Run tests (78 tests)
xcodebuild test \
  -project WorkspaceSwitcher.xcodeproj \
  -scheme WorkspaceSwitcher \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-"

# Regenerate app icon (all sizes from 16px to 1024px)
swift scripts/generate-icon.swift

# Build DMG installer
bash scripts/build-dmg.sh
```

## Releasing

Push a version tag to trigger the [release workflow](.github/workflows/release.yml):

```bash
git tag v1.0.0
git push origin v1.0.0
```

The CI pipeline will:
1. Run the full test suite
2. Build a Release archive
3. Package the `.dmg` installer
4. Create a GitHub Release with the DMG attached

## FAQ

<details>
<summary><strong>Does it store my tokens or passwords?</strong></summary>

WorkspaceSwitcher stores Claude Code OAuth token snapshots in `~/Library/Application Support/WorkspaceSwitcher/workspaces.json`. GitHub credentials are managed entirely by the `gh` CLI and its own keyring — WorkspaceSwitcher only calls `gh auth switch`.
</details>

<details>
<summary><strong>Can I have the same account in multiple workspaces?</strong></summary>

Yes. For example, you can have the same GitHub account in both "Work" and "Personal" workspaces, paired with different Claude Code accounts.
</details>

<details>
<summary><strong>What happens if I switch workspaces while Claude Code is running?</strong></summary>

WorkspaceSwitcher detects running Claude Code sessions and warns you before switching. The credential change takes effect on the next Claude Code invocation.
</details>

<details>
<summary><strong>Does it work with GitHub Enterprise?</strong></summary>

Yes. When logging in with GitHub, the `gh` CLI supports custom hostnames. Accounts from any GitHub Enterprise instance will be detected and managed.
</details>

## License

[MIT](LICENSE)
