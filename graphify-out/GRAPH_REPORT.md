# Graph Report - DASTraderScripts  (2026-10-27)

## Corpus Check
- Corpus: 117 files, approximately 75,819 words. Includes 107 DAS scripts through the project-specific lexical adapter.

## Summary
- 252 nodes · 991 edges · 8 communities
- Extraction: 1 AMBIGUOUS, 985 EXTRACTED, 5 INFERRED
- Token cost: unavailable for semantic extraction; the agent tools expose no usage counters. JSON token fields are zero placeholders, not measured consumption. Structural extraction used no model tokens.

## Graph Freshness
- Refreshed at: 2026-10-28T02:27:17.419228+00:00
- Included working-tree changes: `CHANGELOG.md`, `README.md`, `USERGUIDE.md`, `hotkeys/set_ask_entry_offset_minus_1.das`, `hotkeys/set_ask_entry_offset_minus_2.das`, `hotkeys/set_ask_entry_offset_minus_3.das`, `hotkeys/set_ask_entry_offset_plus_1.das`, `hotkeys/set_ask_entry_offset_plus_3.das`, `hotkeys/set_bid_entry_offset_minus_1.das`, `hotkeys/set_bid_entry_offset_minus_2.das`, `hotkeys/set_bid_entry_offset_minus_3.das`, `hotkeys/set_bid_entry_offset_plus_1.das`, `hotkeys/set_bid_entry_offset_plus_3.das`, `hotkeys/set_global_variables.das`, `hotkeys/short_tier1_ask_minus.das`, `hotkeys/short_tier1_bid_minus.das`, `hotkeys/short_tier2_ask_minus.das`, `hotkeys/short_tier2_bid_minus.das`, `hotkeys/short_tier3_ask_minus.das`, `hotkeys/short_tier3_bid_minus.das`, `hotkeys/short_tier4_ask_minus.das`, `hotkeys/short_tier4_bid_minus.das`, `keymap.yaml`, `tools/tests/trade-isolation.test.cjs`
- File-content provenance is recorded in `graph.json` under `graph.source_snapshot` and in `manifest.json`.
- Built from commit: `aa948053`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Refresh with the graphify workflow plus `extract_das.py`; generic `graphify update .` alone does not understand DAS.

## Community Hubs (Navigation)
- Trading Rules and Risks
- Bindings and Presets
- Regression Test Harness
- Manual Order Execution
- Long Entry Protection
- Exit and Short Protection
- History and Rollback
- Repository Graphify Policy

## God Nodes (most connected - your core abstractions)
1. `Canonical hotkey bindings` - 113 edges
2. `End Trade Action` - 58 edges
3. `Load Trade Context` - 58 edges
4. `Resolve Order Route` - 54 edges
5. `$trade.active` - 53 edges

## Surprising Connections (you probably didn't know these)
- `Canonical hotkey bindings` --references--> `Toggle Rehab Mode`  [EXTRACTED]
  keymap.yaml → hotkeys/enable_rehab_mode.das
- `Canonical hotkey bindings` --references--> `Set Order Route ARCA1L`  [EXTRACTED]
  keymap.yaml → hotkeys/set_order_route_arcal.das

## Import Dependencies
- The test harness imports Node built-ins. Same-file function references are not module import cycles.

## Hyperedges (group relationships)
- **Complete hotkey map and timer installation contract** — readme_build_workflow, keymap_internal_helpers, userguide_timer_runtime [EXTRACTED 1.00]
- **Account/symbol identity across timer, action and alert lifecycles** — userguide_trade_isolation, userguide_registry_lifecycle, userguide_action_lease, userguide_tp_identity [EXTRACTED 1.00]

## Communities (8 total, 0 thin omitted)

### Community 0 - "Trading Rules and Risks"
Cohesion: 0.06168831168831169
Nodes (10): Check Working Sells, Toggle Rehab Mode, Set Global Variables, Switch to Live, Switch to Sim, Timer Event Script, DAS Hotkey Tools VS Code extension, DAS Trader Pro desktop and chart configuration (+2 more)

### Community 1 - "Bindings and Presets"
Cohesion: 0.06060606060606061
Nodes (35): Red microchip-style icon on black, Red rounded-square outline with outward pins on all four sides, Green microchip icon on black background, Bright green microchip outline with perimeter pins, Select Primary Order Entry, Set 0.10 Stop, Set 0.20 Stop, Set 0.30 Stop (+27 more)

### Community 2 - "Regression Test Harness"
Cohesion: 0.06097560975609756
Nodes (26): Load Position Context, Set Order Route ARCA1L, Set Order Route AUTOL, Set Order Route FREE1L, Show Config, node:assert/strict, node:fs, node:path (+18 more)

### Community 3 - "Manual Order Execution"
Cohesion: 0.24324324324324326
Nodes (32): Cover 1/1 Ask+, Cover 1/1 Bid, Cover 1/2 Ask+, Cover 1/2 Bid, Cover 1/4 Ask+, Cover 1/4 Bid, End Trade Action, GTFO (+24 more)

### Community 4 - "Long Entry Protection"
Cohesion: 0.458128078817734
Nodes (29): Buy T3 Ask+ SL, Buy T3 Ask SL, Buy T3 Bid+ SL, Buy T3 Bid SL, Buy T4 Ask+ SL, Buy T4 Ask SL, Buy T4 Bid+ SL, Buy T4 Bid SL (+21 more)

### Community 5 - "Exit and Short Protection"
Cohesion: 0.3006535947712418
Nodes (17): Check Working Buys, $trade.exitGeneration, $trade.exitPending, $trade.exitStage, $trade.generation, $trade.lastStop, $trade.stopArmed, $trade.tpName (+9 more)

### Community 6 - "History and Rollback"
Cohesion: 0.2571428571428571
Nodes (12): 0.1.0 — 2025-12-26, 0.1.1 — 2025-12-29, 0.1.2 — 2026-01-01, 0.1.3 — 2026-01-02, 0.1.4 — 2026-01-08, 0.1.5 — 2026-01-10, 0.2.0 — 2026-01-12, 0.2.1 — 2026-01-15 (+4 more)

### Community 7 - "Repository Graphify Policy"
Cohesion: 0.32727272727272727
Nodes (1): Repository Instructions

## Ambiguous Edges - Review These
- `Documented global configuration defaults` → `Full-position bidirectional breakeven protection`  [AMBIGUOUS]
  USERGUIDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **27 isolated node(s):** `node:assert/strict`, `node:fs`, `node:path`, `node:vm`, `Select Primary Order Entry` (+22 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 47 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Resolve Order Route` connect `Manual Order Execution` to `Trading Rules and Risks`, `Bindings and Presets`, `Regression Test Harness`, `Long Entry Protection`, `Exit and Short Protection`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `Documented global configuration defaults` and `Full-position bidirectional breakeven protection`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
## Extraction Scope and Integrity
- Source snapshot: `aa948053bd61825371385db245babac9809eaf5e`. No hotkeys were compiled, installed, or executed.
- Scope: tracked project files; the ignored `DAS Trader Docs/` vendor PDFs were excluded.
- DAS dependencies are lexical: literal `ExecHotkey` references include generated alert scripts; edges do not assert branch reachability or execution success.
- All 106 keymap hotkeys and the Timer Event Script are represented. Unresolved literal targets: 0.
- Raw integrity check flagged 9 parallel assertions that an undirected graph would collapse. They were consolidated into edge evidence arrays; all original assertions remain in `extraction-evidence.json`.
- Final graph integrity: zero missing endpoints, dangling endpoints, self loops, or unpreserved parallel edges.
- Ambiguous retained relationships: 1. Confidence tags describe evidence, not runtime qualification.
- Small community cohesion values reflect this dependency representation, not proof of a defective module boundary.
- The obsolete USERGUIDE short-protection conflict was removed after a complete reread confirmed consistent automatic short protection.
- All project source paths are repository-relative. Node built-in imports were checked against their current require() lines, including node:assert/strict.
- External Stream Deck profile manifests are outside this repository corpus. Stream Deck descriptions come from project documentation and the two inspected icons, not a live-device qualification.
