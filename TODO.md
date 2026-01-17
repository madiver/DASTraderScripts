# TODO

Feature candidates:
- Max dollar exposure guard (cap by position value).
  Note: confirm DAS hotkeys can reliably read position value or price * shares at entry time.
- Time-window trading lock (disable entries outside defined hours).
  Note: confirm DAS scripting exposes current time/date and supports time comparisons.
- Loss-streak / cooldown guard (pause after N stop-outs).
  Note: confirm we can detect stop-out events vs other exits using available order/position state.
