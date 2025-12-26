// ==============================
// Toggle Visability of Position Windows
// Group: Utilities & toggles
// ==============================

SetFocus Primary_OE;

$pos = GetWindowObj("Positions_Sim");
$pos.AlwaysOnTop;;

$pos = GetWindowObj("Positions_Live");
$pos.AlwaysOnTop;