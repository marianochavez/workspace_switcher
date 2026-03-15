<div align="center">

# WorkspaceSwitcher

### Switch between Claude Code & GitHub accounts from your macOS menu bar

[![Version](https://img.shields.io/github/v/release/marianochavez/workspace_switcher?label=version&color=blue)](https://github.com/marianochavez/workspace_switcher/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com/marianochavez/workspace_switcher/releases)
[![Built with Swift](https://img.shields.io/badge/built%20with-Swift%20%7C%20SwiftUI-orange.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/github/license/marianochavez/workspace_switcher)](LICENSE)

</div>

## Why WorkspaceSwitcher?

Working with multiple Claude Code and GitHub accounts means constantly running `gh auth switch`, editing Keychain entries, and remembering which credentials go together.

**WorkspaceSwitcher** groups your accounts into workspaces and switches them all with a single click from the menu bar — no terminal needed.

## Features

- **One click, all accounts switch** — Claude Code + GitHub credentials swap together
- **Native macOS menu bar app** — lightweight, no Electron, no background daemons
- **Built-in login** — GitHub device code and Claude OAuth flows without leaving the app
- **Custom icons** — monochrome SF Symbols for the menu bar or colorful emoji
- **Launch at login** — starts automatically when you log in

## Installation

> [![Download DMG](https://img.shields.io/github/v/release/marianochavez/workspace_switcher?label=Download%20DMG&color=success&style=for-the-badge)](https://github.com/marianochavez/workspace_switcher/releases/latest)

1. Download the latest **WorkspaceSwitcher-x.x.x.dmg** from [Releases](https://github.com/marianochavez/workspace_switcher/releases/latest)
2. Open the DMG and drag **WorkspaceSwitcher** into your Applications folder
3. Launch the app — it appears in the menu bar (no Dock icon)

<details>
<summary><strong>macOS shows "unidentified developer" — how do I fix it?</strong></summary>

The app is not notarized yet. On first launch:

1. Close the warning dialog
2. Go to **System Settings → Privacy & Security**
3. Click **"Open Anyway"**

After that, the app opens normally.
</details>

## Requirements

Install the CLI tools you want to manage before using WorkspaceSwitcher:

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
- **Menu Bar** — monochrome icons that look native in the macOS status bar
- **Custom** — colorful emoji

### 3. Add Accounts

Use the **Add Accounts** cards in the workspace detail:

| Provider | What happens |
|----------|--------------|
| **GitHub** | The app starts `gh auth login`, shows your one-time device code, copies it to the clipboard, and opens GitHub in the browser. |
| **Claude Code** | The app starts `claude auth login`. Complete the OAuth flow in your browser. |

Accounts that are already added show a green checkmark.

### 4. Switch

Click any workspace in the menu bar dropdown. All associated accounts switch instantly.

```
  ┌───┐
  │ 💼│  ← menu bar
  └─┬─┘
    │
  ┌─▼───────────────────┐
  │ ✓ Work          💼  │
  │   Personal      🏠  │
  │ ─────────────────── │
  │   Settings…     ⌘,  │
  │   Quit          ⌘Q  │
  └─────────────────────┘
```

## FAQ

<details>
<summary><strong>Does it store my tokens or passwords?</strong></summary>

Claude Code OAuth token snapshots are stored locally in `~/Library/Application Support/WorkspaceSwitcher/`. GitHub credentials are managed entirely by the `gh` CLI — WorkspaceSwitcher only tells it which account to activate.
</details>

<details>
<summary><strong>Can I have the same account in multiple workspaces?</strong></summary>

Yes. For example, you can use the same GitHub account in both "Work" and "Personal", paired with different Claude Code accounts.
</details>

<details>
<summary><strong>What happens if I switch while Claude Code is running?</strong></summary>

WorkspaceSwitcher detects running Claude Code sessions and warns you before switching. The credential change takes effect on the next Claude Code invocation.
</details>

<details>
<summary><strong>Does it work with GitHub Enterprise?</strong></summary>

Yes. The `gh` CLI supports custom hostnames, and WorkspaceSwitcher will detect and manage accounts from any GitHub Enterprise instance.
</details>

<details>
<summary><strong>How do I uninstall?</strong></summary>

1. Quit WorkspaceSwitcher from the menu bar
2. Delete `WorkspaceSwitcher.app` from your Applications folder
3. Optionally remove saved data: `rm -rf ~/Library/Application\ Support/WorkspaceSwitcher`

Your CLI tools will continue working normally with whatever account was last active.
</details>

## License

[MIT](LICENSE)
