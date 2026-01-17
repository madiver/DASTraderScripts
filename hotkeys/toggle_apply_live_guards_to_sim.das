// =====================
// TOGGLE LIVE GUARDS IN SIM
// Group: Utilities & toggles
// =====================
// Toggles $applyLiveGuardsToSim (apply live-only guards in SIM).

if ($applyLiveGuardsToSim == 1) {
   $applyLiveGuardsToSim = 0;
   MsgBox("SIM live guards disabled.");
} else {
   $applyLiveGuardsToSim = 1;
   MsgBox("SIM live guards enabled.");
}
