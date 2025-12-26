// =====================
// MANUAL STARTING EQUITY INPUT
// Group: Session equity & PnL
// =====================
// Prompts for a manual starting equity baseline.

// ---- Step 1: Prompt for starting equity ----
$val = Input("Enter Starting Equity", "Type your starting equity amount (e.g., 24500.31)");

// ---- Step 2: Validate input ----
if ($val == "" ) {
    MsgBox("Starting equity not set.");
    return;
}

// Convert to number
$eq = $val * 1;

// Validate numeric range
if ($eq <= 0) {
    MsgBox("Invalid equity value: " + $val + ". Must be a positive number.");
    return;
}

// ---- Step 3: Store into global variable ----
SetVar("DAY_EQUITY_START", $eq);

// ---- Step 4: Inform user ----
MsgBox("Manual starting equity set to: " + $eq);
