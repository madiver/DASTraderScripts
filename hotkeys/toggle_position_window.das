// =====================
// TOGGLE POSITION WINDOW VISIBILITY
// Group: Utilities & toggles
// =====================
// Toggles AlwaysOnTop for the Positions windows.

SetFocus Primary_OE;

$pos = GetWindowObj("Positions_Sim");
if (IsObj($pos)) { $pos.AlwaysOnTop; }

$pos = GetWindowObj("Positions_Live");
if (IsObj($pos)) { $pos.AlwaysOnTop; }
