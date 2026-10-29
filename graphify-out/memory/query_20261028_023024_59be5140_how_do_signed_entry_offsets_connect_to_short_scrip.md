---
type: "query"
date: "2026-10-28T02:30:24.108636+00:00"
question: "How do signed entry offsets connect to short scripts and route selection?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["Quote plus signed offset for buys and shorts", "Short T1 Ask Offset", "Resolve Order Route"]
---

# Q: How do signed entry offsets connect to short scripts and route selection?

## Answer

Offset buys and shorts add the selected signed offset to the reference quote. Negative values price below the quote; positive values price above it. The offset short scripts call Resolve Order Route with the final limit immediately before submission. Confirmed in current USERGUIDE and DAS sources.

## Outcome

- Signal: useful

## Source Nodes

- Quote plus signed offset for buys and shorts
- Short T1 Ask Offset
- Resolve Order Route