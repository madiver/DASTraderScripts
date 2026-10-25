# Repository Instructions

These instructions apply to the entire repository, including generated graph
artifacts under `graphify-out/`.

## DAS hotkey workflow

The user compiles and installs hotkeys into DAS Trader. Make and validate source
changes in this repository, but do not compile hotkey files, load them into DAS,
or change the active DAS hotkey configuration unless the user explicitly asks.

## graphify

The project knowledge graph lives in `graphify-out/graph.json`. Use it to locate
hotkeys, shared trade state, timer handlers, routing, tests, and documentation.

### Query first

- When the user types `/graphify` or invokes the graphify skill, follow the
  installed skill before choosing a build, update, or query workflow. Do not
  rebuild an existing graph just to answer a codebase question.
- For codebase questions and implementation investigations, first run
  `graphify query "<question>"` from the repository root when the graph exists.
  Use `graphify path "<A>" "<B>"` for relationships and
  `graphify explain "<concept>"` for a focused concept. Expand unfamiliar query
  wording against actual graph labels as described in the skill; do not invent
  graph vocabulary or relationships.
- For path queries, use `--undirected` when intentionally ignoring dependency
  direction. A missing directed path does not prove there is no relationship.
- Use the scoped results to choose source files for inspection before editing.
  Prefer this to broad source searches or loading the complete graph JSON.
  If a result is truncated or irrelevant, narrow the query, use path/explain, or
  raise the query budget before concluding the graph has no relevant context.
- If `graphify-out/wiki/index.md` exists, use it for broad navigation. Read
  `graphify-out/GRAPH_REPORT.md` for broad architecture review or when scoped
  queries do not provide enough context.
- Dirty or untracked `graphify-out/` files are expected and are not a reason to
  skip graphify. Respect an explicit user instruction not to use it. When the
  task concerns incorrect graph output, inspect that output and its producers
  directly rather than treating the disputed graph as authoritative.
- If the graph is missing, follow the skill to build it. If the CLI is
  unavailable, use the skill's graph-traversal fallback with an available Python
  runtime. If graph access remains unavailable, explain the limitation briefly
  and continue with targeted source inspection; do not stall an authorized task.

### Freshness and evidence

- Compare the graph's `built_at_commit` with `git rev-parse HEAD`, and inspect
  working-tree changes to scripts, bindings, tests, docs, and assets. A matching
  commit alone does not establish freshness when those files have changed.
  Check `graphify-out/pending-refresh.json` when present; clear pending entries
  only after those files have actually been re-extracted and merged.
- Use stale graph results as navigation hints, then verify relevant current
  source and line locations. Source files and current repository instructions
  take precedence over cached graph claims.
- Preserve EXTRACTED, INFERRED, and AMBIGUOUS distinctions. The current graph is
  undirected: a graph path alone does not establish call direction or runtime
  reachability. Check the source and retained extraction evidence for those.
- A dependency edge or in-memory regression result does not prove installed DAS
  behavior, order acceptance, broker execution, or a fill.

### DAS-aware maintenance

- Keep the graph current after changes to represented source or documentation,
  using the skill's extraction/cache workflow and the project-specific DAS
  adapter. Do not apply COSInstaller's generic `graphify update .` rule here:
  graphify's standard parser does not recognize `.das` files.
  If a complete refresh is outside the task's scope, retain the existing graph
  and explicitly record the changed files as pending; do not claim it is fresh.
- `graphify-out/extract_das.py` extracts literal `ExecHotkey` dependencies,
  keymap references, and selected shared-state references. Merge its new
  `.graphify_das.json` with fresh test-code extraction and current semantic
  doc/image results, replacing obsolete evidence for changed or deleted files.
  Preserve unrelated evidence and the ignored vendor-PDF scope.
- `graphify-out/build_project_graph.py` renders the retained
  `extraction-evidence.json`; it does not perform fresh extraction or merge new
  DAS output automatically. Running the adapter and builder alone is not a
  complete refresh. Update the merged evidence before rendering, and record
  provenance that reflects the inputs actually extracted.
- Preserve source locations, parallel-edge evidence, and graph integrity checks
  when rebuilding `graph.json`, `GRAPH_REPORT.md`, and `graph.html`. Update the
  extraction manifest/cache for files actually processed. Do not relabel an old
  snapshot as current or report unavailable token counts as measured zero.
- If the adapters are absent or incompatible, extend the skill workflow to
  include DAS before replacing the graph. Do not overwrite a useful DAS graph
  with an AST-only graph or install generic automatic update hooks that omit
  DAS. State any remaining stale or unindexed scope explicitly.
- Graph maintenance does not authorize compiling or installing hotkeys,
  changing Stream Deck profiles, or operating the trading application.
