"""Lexical DAS adapter for graphify; reads sources and writes graph sidecars only.

Calls are literal ExecHotkey references, including generated alert payloads.
The graph records dependencies, not reachability, order acceptance, or fills.
"""
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "graphify-out"


def ident(path):
    return re.sub(r"[^a-z0-9_]", "_", str(Path(path).with_suffix("")).lower())


def node_id(path):
    return ident(path) + "_script"


def without_comments(text):
    pattern = r'"(?:\\.|[^"\\])*"|/\*[\s\S]*?\*/|//[^\r\n]*'
    return re.sub(pattern, lambda m: m[0] if m[0].startswith('"') else re.sub(r"[^\n]", " ", m[0]), text)


keymap = (ROOT / "keymap.yaml").read_text()
entries = []
for block in re.split(r"(?m)^- id: ", keymap)[1:]:
    fields = {}
    for name in ("label", "scriptPath", "key"):
        match = re.search(r"(?m)^  " + name + r":[ \t]*([^\r\n]*)", block)
        fields[name] = match[1].strip() if match else ""
    fields["line"] = keymap[:keymap.index("- id: " + block.splitlines()[0])].count("\n") + 1
    entries.append(fields)

by_label = {entry["label"]: entry for entry in entries}
nodes, edges = [], []
keymap_node = "keymap_file"
nodes.append(dict(id=keymap_node, label="Canonical hotkey bindings", file_type="document",
                  source_file=str(ROOT / "keymap.yaml"), source_location="L1"))
paths = sorted({entry["scriptPath"] for entry in entries} | {"other scripts/timer.das"})
source = {path: (ROOT / path).read_text() for path in paths}
script_labels = {entry["scriptPath"]: entry["label"] for entry in entries}
for path in paths:
    nodes.append(dict(id=node_id(path), label=script_labels.get(path, "Timer Event Script"),
                      file_type="code", source_file=str(ROOT / path), source_location="L1",
                      extraction_method="das_lexical", language="DAS"))
for entry in entries:
    edges.append(dict(source=keymap_node, target=node_id(entry["scriptPath"]), relation="references",
                      confidence="EXTRACTED", confidence_score=1.0, weight=1.0,
                      source_file=str(ROOT / "keymap.yaml"), source_location="L" + str(entry["line"]),
                      key_binding=entry["key"] or None))

missing = []
for path, text in source.items():
    clean = without_comments(text)
    found = defaultdict(list)
    for line_no, line in enumerate(clean.splitlines(), 1):
        decoded = line.replace('\\"', '"')
        for match in re.finditer(r'ExecHotkey\s*\(\s*"([^"\r\n]+)"\s*\)', decoded, re.I):
            label = match[1]
            if label not in by_label:
                missing.append(dict(file=path, line=line_no, label=label))
                continue
            found[label].append("L" + str(line_no))
    for label, locations in found.items():
        edges.append(dict(source=node_id(path), target=node_id(by_label[label]["scriptPath"]),
                          relation="calls", confidence="EXTRACTED", confidence_score=1.0, weight=1.0,
                          source_file=str(ROOT / path), source_location=locations[0],
                          source_locations=locations, literal_call_sites=len(locations)))

# Shared lifecycle fields are explicit variable references, not inferred data flow.
fields = ["active", "generation", "entryPending", "entryStage", "entryWatch", "exitPending",
          "exitStage", "exitGeneration", "shortStopPending", "shortStopStage", "lastStop",
          "stopArmed", "tpName", "deferredTp", "deferredBackstop"]
context_path = "hotkeys/load_trade_context.das"
for field in fields:
    pattern = re.compile(r"\$trade\." + re.escape(field) + r"\b", re.I)
    owners = [(p, i) for p, text in source.items() for i, line in enumerate(without_comments(text).splitlines(), 1)
              if pattern.search(line)]
    if not owners:
        continue
    definition = next(((p, i) for p, i in owners if p == context_path), owners[0])
    field_id = ident(context_path) + "_trade_" + field.lower()
    nodes.append(dict(id=field_id, label="$trade." + field, file_type="concept",
                      source_file=str(ROOT / definition[0]), source_location="L" + str(definition[1]),
                      rationale="Account/symbol-bound lifecycle field explicitly referenced by these scripts."))
    for path in sorted({p for p, i in owners}):
        locations = ["L" + str(i) for p, i in owners if p == path]
        edges.append(dict(source=node_id(path), target=field_id, relation="shares_data_with",
                          confidence="EXTRACTED", confidence_score=1.0, weight=1.0,
                          source_file=str(ROOT / path), source_location=locations[0], source_locations=locations))

# Literal test invocations are references, not cross-language call edges.
test_path = "tools/tests/trade-isolation.test.cjs"
test_id = "tools_tests_trade_isolation_test"
test_text = (ROOT / test_path).read_text()
tested = defaultdict(list)
for line_no, line in enumerate(test_text.splitlines(), 1):
    for match in re.finditer(r"\br\.run\(['\"]([^'\"]+)['\"]\)", line):
        if match[1] in by_label:
            tested[match[1]].append("L" + str(line_no))
for label, locations in tested.items():
    edges.append(dict(source=test_id, target=node_id(by_label[label]["scriptPath"]), relation="references",
                      confidence="EXTRACTED", confidence_score=1.0, weight=1.0,
                      source_file=str(ROOT / test_path), source_location=locations[0], source_locations=locations))

result = dict(nodes=nodes, edges=edges, hyperedges=[], input_tokens=0, output_tokens=0)
(OUT / ".graphify_das.json").write_text(json.dumps(result, indent=2))
detect_path = OUT / ".graphify_detect.json"
detection_source = detect_path if detect_path.exists() else OUT / "corpus-inventory.json"
detection = json.loads(detection_source.read_text())
for path in paths:
    absolute = str(ROOT / path)
    if absolute not in detection["files"]["code"]:
        detection["files"]["code"].append(absolute)
        detection["total_files"] += 1
        detection["total_words"] += len(source[path].split())
    if absolute in detection.get("unclassified", []):
        detection["unclassified"].remove(absolute)
detection["custom_extractor"] = "extract_das.py: literal bindings, calls, lifecycle field references; not a DAS parser"
detect_path.write_text(json.dumps(detection, indent=2))
audit = dict(mapped_hotkeys=len(entries), das_files=len(paths), nodes=len(nodes), edges=len(edges),
             missing_literal_targets=missing, code_files=len(detection["files"]["code"]),
             total_files=detection["total_files"], total_words=detection["total_words"])
(OUT / "das-extraction-audit.json").write_text(json.dumps(audit, indent=2))
print(json.dumps(audit, indent=2))
