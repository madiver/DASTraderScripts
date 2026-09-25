// MOMO SWAP INTERNAL
// Group: Utilities & toggles
// Momo invokes this binding after its swap checks; do not use it as the user shortcut.
// The user-facing shortcut calls swap_request.py through ShellExec instead.
$momoPrimary = GetWindowObj("Primary_OE");
$momoSecondary = GetWindowObj("Secondary_OE");
$momoPrimaryChart = GetWindowObj("Primary_Chart");
$momoSecondaryChart = GetWindowObj("Secondary_Chart");
$momoSecondaryTape = GetWindowObj("Secondary_TS");
if (!IsObj($momoPrimary) || !IsObj($momoSecondary) || !IsObj($momoPrimaryChart) || !IsObj($momoSecondaryChart) || !IsObj($momoSecondaryTape)) {
    return;
}
// Capture BOTH original symbols before changing any window.
$momoFirstSymbol = $momoPrimary.Symb;
$momoSecondSymbol = $momoSecondary.Symb;
if ($momoFirstSymbol == $momoSecondSymbol) { return; }
$momoPrimary.Symbol = $momoSecondSymbol;
$momoSecondary.Symbol = $momoFirstSymbol;
$momoPrimaryChart.Symbol = $momoSecondSymbol;
$momoSecondaryChart.Symbol = $momoFirstSymbol;
$momoSecondaryTape.Symbol = $momoFirstSymbol;
