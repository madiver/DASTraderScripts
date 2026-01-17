// =====================
// TOGGLE REHAB MODE
// Group: Utilities & toggles
// =====================
// Toggles $rehab on/off (confirm typed YES to disable).
if ($rehab == 1) {
   $answer = Input("Confirm Rehab Off",
                   "Type YES to confirm you are not emotionally hijacked and want to disable rehab mode:");
   if ($answer != "YES") {
      MsgBox("Rehab mode remains enabled. (You typed: '" + $answer + "')");
      return;
   }
   $rehab = 0;
   MsgBox("Rehab mode disabled.");
} else {
   $rehab = 1;
   MsgBox("Rehab mode enabled.");
}
