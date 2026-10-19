// Group: Utilities & toggles
// Open=0 alone is insufficient: a submit/cancel acknowledgment may still be pending.
$orderClosed = 0;
if (!IsObj($closingOrder)) { return; }
$closingOrder.GetInfo();
if ($closingOrder.Open != 0) { return; }
$closedStatus = StrTrim("" + $closingOrder.Status);
// An explicit rejection also resolves a submission rejected before a RefNum exists.
if ($closedStatus == "Rejected" || $closedStatus == "REJECTED") { $orderClosed = 1; return; }
if ($closingOrder.RefNum <= 0) { return; }
if ($closedStatus == "Canceled" || $closedStatus == "Cancelled" || $closedStatus == "Rejected" || $closedStatus == "Executed" || $closedStatus == "Filled" || $closedStatus == "Expired" ||
    $closedStatus == "CANCELED" || $closedStatus == "CANCELLED" || $closedStatus == "REJECTED" || $closedStatus == "EXECUTED" || $closedStatus == "FILLED" || $closedStatus == "EXPIRED") {
    $orderClosed = 1;
}
// Unknown or nonterminal statuses fail closed and retain the pending exit.
