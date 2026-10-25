# Graph Report - DASTraderScripts  (2026-10-25)

## Corpus Check
- Corpus: 117 files, approximately 75,622 words. Includes 107 DAS scripts through the project-specific lexical adapter.

## Summary
- 217 nodes · 853 edges · 11 communities
- Extraction: 1 AMBIGUOUS, 849 EXTRACTED, 3 INFERRED
- Token cost: unavailable for semantic subagents; their tools expose no usage counters. JSON token fields are zero placeholders, not measured consumption. Structural extraction used no model tokens.

## Graph Freshness
- Refreshed at: 2026-10-25T11:29:56.669596+00:00
- Included working-tree changes: `AGENTS.md`
- File-content provenance is recorded in `graph.json` under `graph.source_snapshot` and in `manifest.json`.
- Built from commit: `67a06e49`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Refresh with the graphify workflow plus `extract_das.py`; generic `graphify update .` alone does not understand DAS.

## Community Hubs (Navigation)
- Regression Test Harness
- Trading Rules and Risks
- Manual Order Execution
- Bindings and Presets
- Long Entry Protection
- Exit and Short Protection
- Repository Graphify Policy
- Initialization and Timer
- History and Rollback
- Momo Swap Qualification
- Account Mode Switching

## God Nodes (most connected - your core abstractions)
1. `Canonical hotkey bindings` - 108 edges
2. `End Trade Action` - 58 edges
3. `Load Trade Context` - 57 edges
4. `Resolve Order Route` - 53 edges
5. `$trade.active` - 53 edges

## Surprising Connections (you probably didn't know these)
- `Proposed pre-trade dollar exposure guard` --semantically_similar_to--> `Entry spread, slippage, size and risk guards`  [INFERRED] [semantically similar]
  TODO.md → USERGUIDE.md
- `Proposed time-window trading lock` --semantically_similar_to--> `AUTOL has no fallback, retry or session gating`  [INFERRED] [semantically similar]
  TODO.md → USERGUIDE.md

## Import Dependencies
- The test harness imports Node built-ins. Same-file function references are not module import cycles.

## Hyperedges (group relationships)
- **Future entry discipline guards that retain exit availability** — todo_time_window_lock, todo_loss_streak_guard, todo_profit_giveback_guard [EXTRACTED 1.00]
- **Account/symbol-owned entry, partial-exit and TP lifecycle** — userguide_trade_isolation, userguide_timer_arming, userguide_partial_exits, userguide_tp_identity, userguide_action_lease [EXTRACTED 1.00]

## Communities (11 total, 0 thin omitted)

### Community 0 - "Regression Test Harness"
Cohesion: 0.07692307692307693
Nodes (26): Load Position Context, Set Order Route ARCA1L, Set Order Route AUTOL, Set Order Route FREE1L, node:assert/strict, node:fs, node:path, node:vm (+18 more)

### Community 1 - "Trading Rules and Risks"
Cohesion: 0.0761904761904762
Nodes (33): Red microchip-style icon on black, Red rounded-square outline with outward pins on all four sides, Green microchip-outline icon on black background, Bright green rounded-square microchip outline with external pins and black center, Green Bid and red Ask offset microchip backgrounds, Profitable scale-in and total planned-stop risk gate, Independent signed Bid and Ask entry offsets, Proposed pre-trade dollar exposure guard (+25 more)

### Community 2 - "Manual Order Execution"
Cohesion: 0.24064171122994651
Nodes (34): Cover 1/1 Ask+, Cover 1/1 Bid, Cover 1/2 Ask+, Cover 1/2 Bid, Cover 1/4 Ask+, Cover 1/4 Bid, End Trade Action, GTFO (+26 more)

### Community 3 - "Bindings and Presets"
Cohesion: 0.0625
Nodes (32): Check Working Sells, Toggle Rehab Mode, Select Primary Order Entry, Set 0.10 Stop, Set 0.20 Stop, Set 0.30 Stop, Set 0.50 Stop, Set Ask Entry Offset -0.01 (+24 more)

### Community 4 - "Long Entry Protection"
Cohesion: 0.4150537634408602
Nodes (31): Buy T3 Ask+ SL, Buy T3 Ask SL, Buy T3 Bid+ SL, Buy T3 Bid SL, Buy T4 Ask+ SL, Buy T4 Ask SL, Buy T4 Bid+ SL, Buy T4 Bid SL (+23 more)

### Community 5 - "Exit and Short Protection"
Cohesion: 0.37142857142857144
Nodes (15): Check Working Buys, $trade.exitGeneration, $trade.exitPending, $trade.exitStage, $trade.generation, $trade.stopArmed, $trade.tpName, Sell 1/2 Ask (+7 more)

### Community 6 - "Repository Graphify Policy"
Cohesion: 0.32727272727272727
Nodes (11): Repository Instructions, DAS-aware extraction and merge requirement, Graph and regression evidence limitations, Graph maintenance operational boundary, Pending-refresh accounting requirement, Graphify query-first investigation workflow, Refresh integrity and provenance requirements, Retained-evidence builder limitation (+3 more)

### Community 7 - "Initialization and Timer"
Cohesion: 0.3611111111111111
Nodes (8): Set Global Variables, Timer Event Script, Documented compilation and installation workflow, DAS Hotkey Tools VS Code extension, Versioned human-readable DAS scripts, Exit coordinator rollback installation procedure, DAS runtime and named window requirements, Four configurable entry tiers and quantity multiplier

### Community 8 - "History and Rollback"
Cohesion: 0.6666666666666666
Nodes (3): Historical and unreleased change records, Retired backstop, dynamic/structured stops and daily loss guard, Restored exit paths retain overlap risk

### Community 9 - "Momo Swap Qualification"
Cohesion: 0.6666666666666666
Nodes (3): Momo Swap Internal, In-memory regression versus DAS qualification, Momo-coordinated two-montage symbol swap

### Community 10 - "Account Mode Switching"
Cohesion: 0.6666666666666666
Nodes (3): Switch to Live, Switch to Sim, SIM/LIVE placeholder substitution

## Ambiguous Edges - Review These
- `Automatic protection for actual short fills` → `Conflicting manual-short protection descriptions`  [AMBIGUOUS]
  USERGUIDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **43 isolated node(s):** `fs`, `path`, `vm`, `root`, `entries` (+38 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Automatic protection for actual short fills` and `Conflicting manual-short protection descriptions`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Resolve Order Route` connect `Manual Order Execution` to `Regression Test Harness`, `Trading Rules and Risks`, `Bindings and Presets`, `Long Entry Protection`, `Exit and Short Protection`?**
  _High betweenness centrality (0.078) - this node is a cross-community bridge._
- **Why does `Load Trade Context` connect `Manual Order Execution` to `Regression Test Harness`, `Trading Rules and Risks`, `Bindings and Presets`, `Long Entry Protection`, `Exit and Short Protection`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
## Extraction Scope and Integrity
- Source snapshot: `67a06e499c119cd997e2e2db0f7101d6246de0e2`. No hotkeys were compiled, installed, or executed.
- Scope: tracked project files; the ignored `DAS Trader Docs/` vendor PDFs were excluded.
- DAS dependencies are lexical: literal `ExecHotkey` references include generated alert scripts; edges do not assert branch reachability or execution success.
- All 106 keymap hotkeys and the Timer Event Script are represented. No unresolved literal targets were found.
- Raw integrity check flagged 20 parallel assertions that an undirected graph would collapse. They were consolidated into edge evidence arrays; all original assertions remain in `extraction-evidence.json`.
- Final graph integrity: zero missing endpoints, dangling endpoints, self loops, or unpreserved parallel edges.
- The documentation contains conflicting descriptions of short protection; the disputed relationship is marked AMBIGUOUS.
- Small community cohesion values reflect this dependency representation, not proof of a defective module boundary.
