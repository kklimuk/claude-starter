# Writing README.md

The README is for humans. CLAUDE.md is for the AI. They overlap, but they have different jobs and different audiences, so don't write one and symlink it as the other.

A human reading the README wants three things, in order:

1. **What is this?** — one paragraph, plain language.
2. **How do I run it?** — exact commands, in order.
3. **How does it work?** — enough mental model to start contributing.

Everything else is optional.

## The shape that holds up

```markdown
# <project name>

<one-paragraph elevator pitch — what it does and who it's for>

## Stack

- **Runtime**: ...
- **Frontend**: ...
- **Database**: ...
- **Quality**: ...

## Getting Started

### Prerequisites
### Setup
### Development

### Commands

| Command | Description |
|---|---|
| ... | ... |

## Architecture

```
src/
  ...
```

## How It Works

<a few prose paragraphs explaining the interesting parts>
```

## Section by section

### Title + tagline

One sentence. State what the thing is in plain language. Avoid "A blazing-fast, type-safe…" — get to the point.

> Inkling: A collaborative text editor inspired by Notion. Real-time multiplayer editing with rich text formatting, a nestable page tree, cursor presence, and persistent storage.

### Stack

A bulleted list with one line per layer (runtime, frontend, backend, db, quality tooling). Link the libraries on first mention. Don't list every transitive dependency.

### Getting Started

Three subsections:

- **Prerequisites** — software the user needs to install before any of the commands work. Pin versions where it matters (`Bun v1.3+`, `PostgreSQL 18`).
- **Setup** — the literal sequence of commands to go from `git clone` to "ready to develop." Include the `.env` file format if there is one.
- **Development** — how to start the dev server, what URL to visit, what the first interaction looks like.

```markdown
### Setup

```bash
bun install
createdb myproject_dev
bun bake db migrate up
```

Create a `.env` file:

```
DATABASE_URL=postgres://localhost:5432/myproject_dev
```

### Development

```bash
bun dev
```

Opens at http://localhost:3000.
```

### Commands

A table. Two columns: command, description. Cover the everyday loop (dev, test, lint, build) and the rarer but important ones (db migrate, db cleanup, format).

The table is read once and referenced repeatedly. Keep descriptions to one line.

### Architecture

A trimmed-down version of the source tree from CLAUDE.md — same structure but pruned to the level a human contributor needs. CLAUDE.md should list every file; the README only needs the ones a human will think about.

### How It Works

This is the section CLAUDE.md doesn't have. Three to six prose paragraphs explaining the interesting parts of the system: the data model, the unusual choices, the trick that makes it work.

> **Editing**: Each page is backed by a single Yjs document. The Tiptap editor binds to a `Y.XmlFragment` inside that doc, and `InklingProvider` syncs changes over WebSocket using the Yjs sync protocol. The server holds Y.Doc instances in memory and persists the encoded state to the `pages.yjs_state` column on a 2-second debounce.

These paragraphs are *narrative*, not reference. They tell a contributor "here's the model in your head you should have before reading the code."

## What does NOT belong in the README

- **Convention rules.** Those go in CLAUDE.md and the linter.
- **Marketing copy.** Save it for the landing page.
- **Auto-generated API docs.** Link to them; don't paste them.
- **A roadmap.** Use issues or a `ROADMAP.md`.
- **A long contributors list.** Put it in `CONTRIBUTORS.md`.
- **A 200-line table of contents.** If the README is long enough to need one, it's too long.

## Length

Aim for 50–150 lines. Past 200, split it: `docs/architecture.md`, `docs/contributing.md`, etc.

## Reference

The README in the `inkling` project this template draws from is a good worked example. Take a look before you start writing your own.
