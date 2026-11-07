# Keypad overlays

Printable overlays for the two keypads Acadia can use, with the game's
own item icons and logo. Each key shows its number and name, with the item's icon printed over the key.
Each sheet holds two overlays (one for each
5200 controller; a spare touch pad one) and a 50 mm bar to check the
print scale.

| Controller | Print sheet | Vector (edit) | Image |
|---|---|---|---|
| Atari 5200 controller | [acadia-5200.pdf](acadia-5200.pdf) | [acadia-5200.svg](acadia-5200.svg) | [acadia-5200.png](acadia-5200.png) (300 dpi) |
| Atari CX21 Video Touch Pad (800/XL/XE, port 2) | [acadia-touchpad.pdf](acadia-touchpad.pdf) | [acadia-touchpad.svg](acadia-touchpad.svg) | [acadia-touchpad.png](acadia-touchpad.png) (300 dpi) |

![5200 overlay](acadia-5200-preview.png) ![Touch Pad overlay](acadia-touchpad-preview.png)

## Printing

1. Print the PDF at **100 % / actual size** (no "fit to page") on matte
   card stock, about 200-250 g/m². The sheet is US Letter; everything
   sits inside A4 too.
2. Measure the 50 mm bar. If it isn't 50 mm, the printer scaled the page.
3. Cut along the **solid black** lines. The art runs 1.5 mm past them
   (to the dotted grey line), so a cut a little outside still looks right.
4. Neither overlay has holes: the keys are pressed through the card,
   as with the originals.

## Keys

| Key | 5200 | Video Touch Pad |
|---|---|---|
| 1-9 | Buy: fort, factory, crops, school, hospital, housing, rebels, PT boat, fishing boat | same |
| 0 | Take the helm of a boat / anchor it | same |
| `*` | Price list | Price list |
| `#` | Hold for the score pages; press again while holding to step | Pause |

On the 5200 the top side button also takes the helm, the bottom one is
fire, and START / PAUSE are the keys above the keypad.

## Sizes

Both outlines are traced from scans of original overlays (5200: QIX;
keypad: Codebreaker), so the shape, the two tabs on each edge and the
key positions keep the originals' proportions. One number sets each
scale, the card's width: `W5200_MM` and `WTP_MM` at the top of
[`tools/mkoverlay.py`](../../tools/mkoverlay.py). **The widths are
estimates**; measure a real overlay and set them.

| | 5200 | Touch Pad |
|---|---|---|
| Card width (sets the scale) | 51 mm (estimate) | 64 mm (estimate) |
| Card height, without tabs | 77.5 mm | 95.2 mm |
| Top tabs (w × h, from left edge) | 6.9 × 2.2 mm at 11.6 and 32.6 mm | 9.4 × 3.3 mm at 9.3 and 45.3 mm |
| Bottom tabs | 4.3 × 2.4 mm at 6.3 and 39.9 mm | 9.5 × 3.3 mm at 5.7 and 48.7 mm |
| Key pitch (centres) | 15.9 × 15.7 mm | 19.6 × 19.6 mm |
| Key area (originals' frames) | 9.7 × 5.9 mm | 14 × 9.1 mm |

To change them, edit the numbers and rebuild:

```sh
python3 -I tools/mkoverlay.py      # the SVGs (needs: pip install potracer)
node tools/overlay_render.js       # PDF + PNG (needs Node + Playwright with Chromium)
```
