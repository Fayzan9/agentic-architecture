# docs/sources

This folder holds two kinds of things — one tracked in git, one not.

## Tracked (our own work)

- `*-reference.md` — hand-built navigation maps for each vendored SDK (module tree + "I want to..." lookup tables). Start here, not the raw source.
- `adk-comparison.md` — a detailed feature comparison across the three SDKs.

## Not tracked — fetched on demand

- `adk-python/`, `openai-agents-python/`, `claude-agent-sdk-python/` — full clones of the upstream SDK repos. These are **gitignored on purpose**: we want everyone working in this repo to read the actual, current upstream source, not a copy that silently goes stale the moment it's committed.

Run this after cloning the repo, and any time you want a refresh:

```bash
./scripts/fetch-docs.sh
```

It clones each SDK fresh (or fast-forwards it to latest if already present). Consider wiring it into a daily cron job if you want these always up to date without thinking about it:

```cron
0 6 * * * cd /path/to/this/repo && ./scripts/fetch-docs.sh >> /tmp/fetch-docs.log 2>&1
```

If a reference map ever seems to disagree with the actual source, trust the source — and update the reference map to match.
