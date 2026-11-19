# lsdocs-bench

Part of [lsdocs](https://github.com/lsdocs), a static-site generator whose
parsers, transformers and renderers are plugins.

Build benchmarks: `nur bench [--pages N] [--runs N]` generates a
synthetic site and times `lsdocs build` (release) on it with the
first-party plugins in-process, out-of-process over stdio and over a
pipe, with and without the cache, and with big pages. lsdocs is installed
from git (or `LSDOCS_BIN` names a binary). Results and the decisions they
led to are in lsdocs' ROADMAP.md (Phase 7).

## Known limitations

- Times one machine's builds; nothing tracks results over time.

## TODO

- [ ] Keep results per lsdocs revision to spot regressions.
