# Working in This Codebase

This repository uses Tuist to define and generate the Xcode project, and a Makefile to provide consistent, repeatable workflows. Prefer the provided make targets over running raw commands directly.

## Prerequisites
- Xcode 16+ with the iOS 18 SDK (Swift 6).
- Tuist installed and available on your PATH. If not, the Makefile will attempt to use `mise` to run Tuist if present.

## Daily Workflow
- Generate and open the workspace: `make open`
  - This runs Tuist to generate the project and opens it in Xcode.
- Regenerate after manifest changes: `make reload`
  - Use this after editing `Project.swift` (or any files under `Tuist/`).
- Clean and fully reinstall Tuist deps: `make clean`
  - Runs `tuist install` then regenerates, useful if generation drifts or versions change.
- Build the SDK framework (no simulator launch): `make build`
- Build the example iOS app target (no simulator launch): `make build-example`

## Source Layout
- SDK sources: `Sources/GenMark/**`
- Example app: `Examples/GenMarkExample/**` (assets under `Resources` per `Project.swift`)
- SwiftPM package manifest: `Package.swift` (used for module structure and tests)
- Tuist project manifest: `Project.swift` (single source of truth for Xcode project)

## Quick Reference
- `make open`: generate + open workspace
- `make reload`: regenerate without opening
- `make clean`: reinstall Tuist deps + regenerate
- `make build`: build `GenMark` (framework) for iOS Simulator
- `make build-example`: build `GenMarkExample` app for iOS Simulator

## Build & Test Gate (Run After Every Change)
- Ensure toolchain: `tuist version` should be `4.66.1`; select Xcode 16 with `sudo xcode-select -s /Applications/Xcode.app`.
- First-time setup: `tuist install && tuist fetch` (and `mise trust` if prompted).
- Re-generate on manifest edits: `make reload` (safe to skip for `make build`/`make test`).
- Build SDK: `make build` (uses `tuist build GenMark --configuration Debug`).
- Build example app: `make build-example` (uses `tuist build GenMarkExample --configuration Debug`).
- Run unit tests: `make test` (uses `tuist test --configuration Debug`).
- If Tuist reports caching/manifest issues: `tuist clean && tuist fetch`, then rerun the above.
- If tests are not discovered via Tuist, run `swift test` as a fallback (SPM runner).

Treat “build + tests green” as the acceptance gate for any code change before commit/PR.

## MCP (Context7) Integration
- Overview: MCP lets tools like Codex/Claude connect to external servers for context. We ship a scaffold under `mcp/` to hook up the Context7 MCP server.
- Where to start: See `mcp/README.md` for client-specific steps and a `context7.example.json` you can copy and fill with your credentials and transport (stdio or SSE).
- What we need from you: Confirm the MCP client (Codex CLI, Claude Desktop, etc.), transport (stdio vs. SSE URL), and provide your Context7 API key.
