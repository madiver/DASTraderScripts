// =====================
// TOGGLE SPREAD CHECK
// Group: Utilities & toggles
// =====================
// Toggles the $useSpreadCheck safety guard.

if ($useSpreadCheck== 1) {
   $useSpreadCheck=0;
   MsgBox("WARNING: spread check disabled.");
} else {
   $useSpreadCheck=1;

}
