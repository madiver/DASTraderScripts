// =====================
// TOGGLE LIVE GUARDS IN SIM
// Group: Utilities & toggles
// =====================
// Toggles $applyLiveGuardsToSim (apply live-only guards in SIM).

if ($applyLiveGuardsToSim == 1) {
   $applyLiveGuardsToSim = 0;
   MsgLog("SIM live guards disabled.");
} else {
   $applyLiveGuardsToSim = 1;
   MsgLog("SIM live guards enabled.");
}
