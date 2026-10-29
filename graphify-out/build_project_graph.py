"""Build a graphify map from retained evidence, preserving parallel assertions.

Refresh DAS evidence with extract_das.py and repeat the graphify semantic workflow
after source changes. Generic graphify update alone cannot parse .das files.
"""
import argparse
import copy
import json
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

from graphify.analyze import god_nodes, suggest_questions, surprising_connections
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.diagnostics import diagnose_extraction, format_diagnostic_report
from graphify.export import to_html, to_json
from graphify.report import generate

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "graphify-out"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--accept-removed-node", action="append", default=[],
                    help="Acknowledge an individually verified obsolete node; all removed IDs must match exactly")
args = parser.parse_args()
LABELS = {
    0: "Regression Test Harness",
    1: "Bindings and Presets",
    2: "Manual Order Execution",
    3: "Trading Rules and Risks",
    4: "Long Entry Protection",
    5: "Exit and Short Protection",
    6: "Initialization and Timer",
    7: "Stream Deck Controls",
    8: "History and Rollback",
    9: "Momo Swap Qualification",
    10: "Account Mode Switching",
    11: "Source Change Policy",
}

raw = json.loads((OUT / "extraction-evidence.json").read_text(encoding="utf-8"))
raw_health = diagnose_extraction(copy.deepcopy(raw), directed=False, root=str(ROOT))
(OUT / "raw-extraction-health.json").write_text(json.dumps(raw_health, indent=2))

# An undirected Graph has one edge per endpoint pair. Preserve every assertion
# inside its edge instead of letting NetworkX overwrite source locations.
pairs = defaultdict(list)
for edge in raw["edges"]:
    pairs[tuple(sorted((edge["source"], edge["target"])))].append(edge)
canonical = copy.deepcopy(raw)
canonical["edges"] = []
for evidence in pairs.values():
    primary = max(evidence, key=lambda e: (bool(e.get("source_location")), e.get("confidence_score", 0)))
    edge = copy.deepcopy(primary)
    edge["evidence_count"] = len(evidence)
    if len(evidence) > 1:
        edge["evidence"] = evidence
    canonical["edges"].append(edge)
(OUT / ".graphify_extract.json").write_text(json.dumps(canonical, indent=2))
(OUT / "canonical-extraction.json").write_text(json.dumps(canonical, indent=2))
health = diagnose_extraction(copy.deepcopy(canonical), directed=False, root=str(ROOT))
(OUT / "graph-health.json").write_text(json.dumps(health, indent=2))
print(format_diagnostic_report(health))
integrity_keys = ("missing_endpoint_edges", "dangling_endpoint_edges", "self_loop_edges",
                  "undirected_same_endpoint_collapsed_edges")
if any(health.get(key, 0) for key in integrity_keys):
    raise RuntimeError("Graph integrity failed; retained graph outputs were not replaced")

G = build_from_json(copy.deepcopy(canonical), directed=False, root=str(ROOT))
if not G.number_of_nodes():
    raise RuntimeError("Empty graph; refusing to replace outputs")
if raw.get("source_snapshot"):
    G.graph["source_snapshot"] = raw["source_snapshot"]
if raw.get("intentional_removed_nodes"):
    G.graph["intentional_removed_nodes"] = raw["intentional_removed_nodes"]
communities = cluster(G)
cohesion = score_all(G, communities)
# Community numbers can change when a disconnected documentation fragment grows.
# Match prior names by node overlap instead of attaching old names to new IDs.
prior_analysis_path = OUT / "community-analysis.json"
prior_labels_path = OUT / ".graphify_labels.json"
prior_analysis = json.loads(prior_analysis_path.read_text(encoding="utf-8")) if prior_analysis_path.exists() else {}
prior_labels = json.loads(prior_labels_path.read_text(encoding="utf-8")) if prior_labels_path.exists() else {}
labels = {}
for cid, members in communities.items():
    matches = [(len(set(members) & set(old_members)), old_id)
               for old_id, old_members in prior_analysis.get("communities", {}).items()]
    best = max(matches, default=(0, ""))
    labels[cid] = (prior_labels.get(str(best[1])) if best[0] else None) or LABELS.get(cid, "Project Subsystem " + str(cid))
    if "agents_graphify_query_first" in members:
        labels[cid] = "Repository Graphify Policy"
gods = god_nodes(G)
surprises = surprising_connections(G, communities)
questions_all = suggest_questions(G, communities, labels)
questions = [q for q in questions_all if q["type"] == "ambiguous_edge"][:1]
questions += [q for q in questions_all if q["type"] == "bridge_node" and
              ("Resolve Order Route" in q["question"] or "Load Trade Context" in q["question"])][:2]
detection_path = OUT / ".graphify_detect.json"
if not detection_path.exists():
    detection_path = OUT / "corpus-inventory.json"
detection = json.loads(detection_path.read_text(encoding="utf-8"))
audit = json.loads((OUT / "das-extraction-audit.json").read_text(encoding="utf-8"))
detection["warning"] = (f"Corpus: {detection['total_files']} files, approximately {detection['total_words']:,} words. "
                        f"Includes {audit['das_files']} DAS scripts through the project-specific lexical adapter.")
(OUT / ".graphify_detect.json").write_text(json.dumps(detection, indent=2))
commit = raw.get("source_commit") or subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
accepted_removals = set(args.accept_removed_node)
if accepted_removals:
    previous = json.loads((OUT / "graph.json").read_text(encoding="utf-8"))
    removed = {node["id"] for node in previous["nodes"]} - set(G.nodes)
    documented = set(raw.get("intentional_removed_nodes", {}))
    if removed != accepted_removals or not accepted_removals <= documented:
        raise RuntimeError("Acknowledged removals must exactly match the missing nodes and their retained reasons")
    G.graph["intentional_removed_nodes"] = raw["intentional_removed_nodes"]
if not to_json(G, communities, str(OUT / "graph.json"), community_labels=labels, built_at_commit=commit,
               force=bool(accepted_removals)):
    raise RuntimeError("Graph export shrink guard refused output")
report = generate(G, communities, cohesion, labels, gods[:5], surprises[:2], detection,
                  {"input": 0, "output": 0}, str(ROOT), suggested_questions=questions,
                  min_community_size=1, built_at_commit=commit)
confidence = Counter(e.get("confidence", "EXTRACTED") for e in canonical["edges"])
report = re.sub(r"- Extraction:.*", "- Extraction: " + ", ".join(f"{v} {k}" for k, v in sorted(confidence.items())), report)
report = report.replace("- Token cost: 0 input · 0 output",
                        "- Token cost: unavailable for semantic extraction; the agent tools expose no usage counters. "
                        "JSON token fields are zero placeholders, not measured consumption. Structural extraction used no model tokens.")
report = report.replace("- Run `graphify update .` after code changes (no API cost).",
                        "- Refresh with the graphify workflow plus `extract_das.py`; generic `graphify update .` alone does not understand DAS.")
report = re.sub(r"## Import Cycles\n.*?(?=\n## )",
                "## Import Dependencies\n- The test harness imports Node built-ins. Same-file function references are not module import cycles.\n",
                report, flags=re.S)
for cid, value in cohesion.items():
    report = re.sub(r"(### Community " + str(cid) + r" - [^\n]+\nCohesion: )[^\n]+",
                    lambda m: m[1] + str(value), report)
report = re.sub(r"^- \*\*\d+ thin communities.*\n", "", report, flags=re.M)
snapshot = raw.get("source_snapshot", {})
if snapshot:
    dirty = snapshot.get("uncommitted_indexed_files", [])
    report = report.replace("## Graph Freshness\n", "## Graph Freshness\n" +
        "- Refreshed at: " + snapshot.get("refreshed_at", "unknown") + "\n" +
        "- Included working-tree changes: " + (", ".join(f"`{p}`" for p in dirty) or "none") + "\n" +
        "- File-content provenance is recorded in `graph.json` under `graph.source_snapshot` and in `manifest.json`.\n")
consolidated = len(raw["edges"]) - len(canonical["edges"])
report += ("\n## Extraction Scope and Integrity\n"
           f"- Source snapshot: `{commit}`. No hotkeys were compiled, installed, or executed.\n"
           "- Scope: tracked project files; the ignored `DAS Trader Docs/` vendor PDFs were excluded.\n"
           "- DAS dependencies are lexical: literal `ExecHotkey` references include generated alert scripts; edges do not assert branch reachability or execution success.\n"
           f"- All {audit['mapped_hotkeys']} keymap hotkeys and the Timer Event Script are represented. "
           f"Unresolved literal targets: {len(audit['missing_literal_targets'])}.\n"
           f"- Raw integrity check flagged {consolidated} parallel assertions that an undirected graph would collapse. "
           "They were consolidated into edge evidence arrays; all original assertions remain in `extraction-evidence.json`.\n"
           "- Final graph integrity: zero missing endpoints, dangling endpoints, self loops, or unpreserved parallel edges.\n"
           f"- Ambiguous retained relationships: {confidence.get('AMBIGUOUS', 0)}. Confidence tags describe evidence, not runtime qualification.\n"
           "- Small community cohesion values reflect this dependency representation, not proof of a defective module boundary.\n")
for note in raw.get("extraction_notes", []):
    report += "- " + note + "\n"
(OUT / "GRAPH_REPORT.md").write_text(report, encoding="utf-8")
(OUT / ".graphify_labels.json").write_text(json.dumps({str(k): v for k, v in labels.items()}, indent=2))
(OUT / "community-analysis.json").write_text(json.dumps(dict(communities=communities, cohesion=cohesion,
    gods=gods, surprises=surprises, questions=questions), indent=2))
if G.number_of_nodes() > 5000:
    raise RuntimeError("More than 5,000 nodes; ask before visualization")
if not to_html(G, communities, str(OUT / "graph.html"), community_labels=labels):
    raise RuntimeError("HTML visualization was not written")
print(f"Final graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities")
print(f"Consolidated {consolidated} parallel assertions with their evidence preserved")
