# Offset toggle backgrounds

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
