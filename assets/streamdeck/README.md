# Stream Deck assets and local setup

The repository stores background images and an installation receipt, not an
importable Stream Deck profile. Profiles live outside Git. Configure button
shortcuts from [keymap.yaml](../../keymap.yaml) after installing the matching DAS
hotkey map; the receipt does not install buttons on another machine.

## Offset toggle backgrounds

- `bid-offset-green.png`: green microchip outline for BID OFFSET.
- `ask-offset-red.png`: red microchip outline for ASK OFFSET.

Color references were sampled from the existing DAS Trader profile: buy background
`#00FF00`, sell background `#FF0000`. Both icons keep a black interior and background;
the plugin draws the offset value and label separately. The same icon is used for
all five states on each side.

Created with the built-in image generation/editing tool from the existing blue
microchip background, then downscaled to 156 x 160 pixels for Stream Deck.

## Green edit prompt

Use case: precise-object-edit. Edit target: image 1, a 78x80 pixel Stream Deck button background showing a blue microchip outline and pins on a uniform very dark background. Supporting color reference: image 2 is the existing buy button whose green is exactly sRGB #00FF00 (RGB 0,255,0). Perform ONLY a precise color replacement of the blue microchip outline and its pins with that exact #00FF00 green. Preserve the original chip geometry, stroke thickness, rounded corners, pin positions and counts, scale, margins, 78:80 aspect ratio, empty chip interior, and every dark background area exactly as in image 1. Keep antialiased outline edges. Output a single standalone icon, ideally at its original 78x80 dimensions. No text, no added labels, no filled green interior, no green background, no glow, no shadows, no gradients, no extra elements. This is a strict recolor of the original icon, not a redesign.

## Red edit prompt

Use case: precise-object-edit. Edit target: image 1, a 78x80 pixel Stream Deck button background showing a blue microchip outline and pins on a uniform very dark background. Supporting color reference: image 2 is the existing sell button whose red is exactly sRGB #FF0000 (RGB 255,0,0). Perform ONLY a precise color replacement of the blue microchip outline and its pins with that exact #FF0000 red. Preserve the original chip geometry, stroke thickness, rounded corners, pin positions and counts, scale, margins, 78:80 aspect ratio, empty chip interior, and every dark background area exactly as in image 1. Keep antialiased outline edges. Output a single standalone icon, ideally at its original 78x80 dimensions. No text, no added labels, no filled red interior, no red background, no glow, no shadows, no gradients, no extra elements. This is a strict recolor of the original icon, not a redesign.

## Entry timeout buttons

Two Advanced Toggles cycle actions are on settings page 5 of both physical and
Virtual DAS Trader profiles. Their local positions, verified on 2026-10-30, are:

| Button | Location (human numbering) | Choices | Shortcuts in choice order |
| --- | --- | --- | --- |
| LONG TIMEOUT | Row 3, column 7 (`6,2`) | 10s, 15s, 30s, INDEF | Ctrl+Alt+Shift+F9/F10/F11/F12 |
| SHORT TIMEOUT | Row 3, column 8 (`7,2`) | 10s, 15s, 30s, INDEF | Ctrl+Alt+F9/F10/F11/F12 |

The buttons reuse the green/red offset backgrounds, enable four states, start
at 10s, and disable the remaining two plugin states. They do not control sizing
mode actions or synchronize across keys/profiles. Every press sends an explicit
preset for future entries; it does not change a pending entry's captured deadline.
Long and short defaults in DAS are independent and both start at 10s.

Both timeout buttons use Toggle Group 5 as a reset-only group, with
`syncAcrossKeys: false` and `controlsModeActions: false`. LOAD CFG runs the
existing configuration hotkey, then its existing offset resets, then a group-5
Reset Group action with `resetState: 0` and `sendTargetHotkeys: false`. This sets
both timeout displays to 10s; the configuration hotkey sets both DAS defaults.
Inactive profile buttons apply the recorded reset when they next appear.
Individual LONG/SHORT presses remain independent and do not synchronize between
profiles. The BID/ASK controls keep groups 3/4 and their original reset states
3/2 (+1/-1 cent); all original LOAD CFG steps are preserved.

Reset Group applies to every member of its group even when sync across keys is
off. The timeouts previously inherited offset groups 3/4, causing LOAD CFG's
offset resets to select LONG INDEF and SHORT 30s. Do not reuse an offset group
for a timeout selector.

Restarting DAS or running Set Global Variables directly still resets only DAS
defaults. Use LOAD CFG or select explicit presets to align the displays with
DAS after those actions or after switching profiles with different selections;
the display is not live feedback from DAS.

[entry-timeout-installation.json](entry-timeout-installation.json) records the
profile/page identities, backup location, and last verification. On 2026-10-30,
both saved profiles passed in-memory checks using the installed plugin's reset
and cycle functions: offset isolation, both timeout displays resetting to 10s,
deferred resets for inactive controls, independent cycling and no selector
hotkeys during resets. The physical profile visibly rendered LONG and SHORT at
10s after the repair. LOAD CFG itself was not executed against DAS during this
verification.

Advanced Toggles initially unloaded with “missing ownership verification” on
relaunch, then loaded successfully after a local plugin installation appeared in
the app log. The final visual check showed working labels. Plugin availability
is still required for all toggle/reset actions. No profile export, plugin
license, or broker/DAS configuration is supplied here.
