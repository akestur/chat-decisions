# chat-decisions

A Cowork / Claude Code plugin that visualizes the decisions you've made in a chat as an interactive tree.

When you iterate with Claude over many turns — building a webapp, designing a project, scoping a research direction — you make a lot of small choices. Claude tends to present these as numbered options ("here are three approaches: A, B, C"), and you pick one each time. This plugin extracts those choice-points from the conversation and renders them as a vertical trunk-and-branches SVG:

- Picked options form a **trunk** running top to bottom.
- Rejected options **branch off** as short dead-ends.
- **Pivot badges** mark moments where you abandoned all options and changed direction.

## Install

### Option 1: Download a pre-built `.plugin` file (recommended)

1. Go to the [Releases](https://github.com/YOUR_USERNAME/chat-decisions/releases) page.
2. Download the latest `chat-decisions.plugin`.
3. In Cowork: drop the file into a chat, then click "Save plugin."

### Option 2: Build from source

```bash
git clone https://github.com/YOUR_USERNAME/chat-decisions.git
cd chat-decisions
./build.sh
```

This produces `chat-decisions.plugin` in the repo root. Install it the same way as Option 1.

## Use

In any Cowork chat, type:

```
/chat-decisions
```

The plugin reads the current chat, extracts the choice-points, and renders the tree inline. Takes ~15–25 seconds for a typical chat with 5–10 decisions.

## Triggering

This plugin is **explicit-invocation only**. It does not auto-trigger on natural-language phrases like "show me my decisions" or "visualize my choices" — you have to type the slash command literally. This is deliberate: the goal is for the plugin to stay out of your way until you actively ask for it.

## Environments

| Environment | Rendering |
|---|---|
| Cowork / Claude desktop | Inline SVG widget |
| Claude Code (terminal) | Standalone HTML file written to `./chat-decisions.html` |

The plugin auto-detects which path is available. In Claude Code, open the saved HTML file in any browser to view the tree.

## How it works

On invocation, the plugin's command body instructs Claude to:

1. Scan the current chat's message history (already in Claude's context).
2. Identify **choice-points** — places where Claude offered discrete enumerated options and you picked one (or pivoted away).
3. Produce a structured JSON array describing each decision: question, options offered, which one was picked.
4. Inject that JSON into a self-contained SVG/JS template and render it via the visualize widget (Cowork) or write it as a standalone HTML file (Claude Code).

The extraction rules — what counts as a choice-point vs. what doesn't, how to handle implicit picks and pivots — are documented in `commands/chat-decisions.md`.

## Limitations

- **Single-chat scope.** Only sees the current conversation. If you've worked on a project across multiple chats, this won't aggregate them.
- **Macro-decisions only.** Captures architectural / strategic choices, not micro choices (label text, emoji picks).
- **Render scales linearly.** Trees with 20+ decisions take longer (~30–60s) and get tall. For very long chats, a future v2 may switch to a collapsible tree.
- **Description-based auto-invocation isn't fully blocked.** The plugin tries hard to discourage auto-invocation via the Skill tool, but the underlying mechanism is a behavioral hint to Claude, not a protocol-level guarantee. Edge cases may slip through.

## Versioning

Current version: **1.2.0**. Semantic versioning. Release notes in the GitHub Releases tab.

## Contributing

Issues and PRs welcome. The whole plugin is ~340 lines of markdown and JSON across two files, so it's easy to read and modify.

## License

MIT — see [LICENSE](./LICENSE).
