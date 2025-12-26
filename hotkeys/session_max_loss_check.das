// ================================
// MANUAL STARTING EQUITY INPUT
// Group: Session equity & PnL
// ================================

// Ask user for starting equity
$val = Input("Enter Starting Equity", "Type your starting equity amount (e.g., 24500.31)");

// If user cancelled or left blank, stop
if ($val == "" ) {
    MsgBox("Starting equity not set.");
    return;
}

// Convert to number
$eq = $val * 1;

// Validate
if ($eq <= 0) {
    MsgBox("Invalid equity value: " + $val + ". Must be a positive number.");
    return;
}

// Store into global variable
SetVar("DAY_EQUITY_START", $eq);

// Inform user
MsgBox("Manual starting equity set to: " + $eq);