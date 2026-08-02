# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native macOS menu bar app (Swift Package, no Xcode project) that shows the
logged-in Claude Code account and 5h/7d usage-window utilization as an
`NSStatusItem`. No Electron, no third-party dependencies, nothing written to
disk — it only reads the Keychain and `~/.claude.json` and calls Anthropic's
usage API with the token the `claude` CLI already has.

## Commands

```bash
swift build                        # debug build
./build.sh                         # release build -> ./claude-usagebar
./claude-usagebar &                # run it (menu bar icon, no Dock icon)
./install-agent.sh                 # deploy release binary as a LaunchAgent (autostart at login)
./uninstall-agent.sh               # remove the LaunchAgent + installed copy
```

There is no test target and no linter configured — the package is
`.executableTarget(name: "ClaudeUsageBar")` only.

`install-agent.sh` copies `./claude-usagebar` to
`~/Library/Application Support/ClaudeUsageBar/` and points the LaunchAgent
there, not at the repo checkout — after installing, the checkout can be
deleted and the app keeps running. To ship a code change: `./build.sh` then
`./install-agent.sh` again (it reloads the LaunchAgent). The binary copy
uses a copy-then-rename instead of an in-place overwrite, because
overwriting an already-run ad-hoc-signed binary at the same inode on Apple
Silicon can leave the kernel's code-signing cache stale ("load code
signature error 2") and kill the process moments after launch.

## Architecture

Strict one-directional layering, each layer with exactly one job — this is
the thing to preserve when adding code, not just a description of what
exists today:

- **Models** (`Models/`) — only decode JSON / represent data. No I/O, no logic.
- **Credentials** (`Credentials/`) — the only place allowed to touch the
  Keychain (`CredentialsStore.readKeychainItem`, via `/usr/bin/security`,
  service name `Claude Code-credentials`) or `~/.claude.json`. Read-only,
  always; never writes back, even on token refresh.
- **Networking** (`AnthropicUsageAPI.swift`) — the only place allowed to hit
  the network. Calls `GET https://api.anthropic.com/api/oauth/usage` with
  the OAuth bearer token; a refresh-token flow rotates an expired access
  token in memory only (never persisted, so it can't desync from the
  `claude` CLI's own credential state).
- **Formatting** (`UsageFormatter.swift`) — pure functions only (percent,
  date, text-bar rendering). No AppKit, no I/O.
- **Localization** (`Localization/`) — `L10n` is every user-facing string in
  one enum namespace; `AppLanguage` is the EN/PT-BR toggle persisted in
  `UserDefaults`, independent of macOS system language.
- **UI** (`UI/`) — the *only* layer allowed to touch AppKit state.
  `StatusBarController` is the sole class in the app that mutates anything;
  everything below it is a value type or a stateless enum namespace.
  `UsageMenuBuilder.build` is a pure function from state (`MenuContent`) to
  `NSMenu` — it never touches `StatusBarController`'s internals directly.

Control flow: `App.swift` (`@main`, `NSApplicationDelegate`) creates the one
`StatusBarController` on launch. `StatusBarController.refresh()` runs on a
60s `Timer` plus on-demand ("Refresh now" menu item / language switch), reads
credentials, calls the usage API, and re-renders. `applyRender()` redraws
from cached `currentIcon`/`currentTitle`/`currentContent` state so a plain
language switch (`selectLanguage`) redraws instantly without a network round
trip. `refresh()` guards against overlap with `isRefreshing`.

When adding a feature, put it in the layer that matches its job rather than
extending `StatusBarController` — e.g. a new formatted string goes in
`UsageFormatter` + `L10n`, not inline in the controller.
