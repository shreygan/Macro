# Custom SF Symbols

Custom drink symbols for Macro are generated from code, not drawn by hand. Each symbol is a Python function in `symbols.py` that writes an SF Symbols **Template v4.0** SVG with Ultralight, Regular and Black masters, so every weight interpolates. `symbols.py` is the source of truth: never hand-edit the generated SVGs in the asset catalog.

This folder sits outside `Macro/` on purpose. `Macro/` is a synced Xcode group, so files placed there join the app target (and `sheet.swift` would be compiled into the app).

## Layout

| Path | Purpose |
|---|---|
| `symbols.py` | All symbol geometry + template writer. `SHAPES` registry at the bottom. |
| `preview.sh` | Compiles symbols with `actool` and renders `previews/sheet.png` (or `--zoom` → `previews/zoom.png`). |
| `sheet.swift` | Renderer used by `preview.sh`. Custom symbols draw blue, system references black. |
| `export.sh` | Writes `.symbolset` folders into `Macro/Resources/Assets.xcassets` (Xcode-formatted `Contents.json`). |
| `previews/`, `.build/` | Generated output, git-ignored. |

## Commands

```sh
cd Tools/Symbols
./preview.sh                                     # every custom symbol, between waterbottle.fill and mug.fill
./preview.sh bottle.squeeze.fill                 # just the names given
./preview.sh --zoom carton.fill                  # 220pt close-up for checking corners and gaps
./preview.sh --zoom pitcher.fill mug.fill        # system names render as black references
./export.sh                                      # write all symbolsets into the app
./export.sh carton.fill                          # write one
```

## Process for a new symbol

1. **Check built-ins first.** Search the system name list:
   `plutil -convert json -o - /System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist`
   Only go custom if nothing fits.
2. **Vet before drawing** when asked for several shapes: name each one's signature feature, rate feasibility at 15–17pt, flag pairs that could collide, and suggest additions or cuts. Get sign-off first.
3. **Write the function** in `symbols.py` and register it in `SHAPES`.
   - `fn(g, t)` with `scaled=True`: drawn once in Regular coordinates; width scales per weight (0.96 / 1.0 / 1.06). `g` = cut gap (2.4 / 3.5 / 5.0), `t` = loop/handle thickness (4.5 / 6.0 / 8.0).
   - `fn(i)` with `scaled=False`: explicit per-weight table, or `WEIGHT_PARAMS[i]` for round shapes that must not stretch (can, glass, coconut, citrus).
4. **Preview** with `preview.sh`, then `--zoom` on anything with joints, loops or multiple panels. Inspect the image before showing it.
5. **Export** with `export.sh`, then in `Macro/Models/Types/DrinkSymbol.swift` add the name to `DrinkSymbol.custom` and add an `option("name", "VoiceOver label")` to the right entry in `DrinkSymbol.groups` (Water, Bottles, Coffee & Tea, Soda & Juice, Alcohol, Other). Each group is its own card in the icon picker. Labels are short, generic and spoken by VoiceOver, so no brand names. Every drink icon site renders through `Image(symbol:)`, which loads asset symbols for names in `custom`.
6. **Build** the app and confirm the symbol is in the compiled `Assets.car` (`xcrun assetutil --info … | grep <name>`).

## Metrics (template units, Small scale, 100pt)

- The template is drawn at **Small** scale. System symbols measured at the default Medium scale come out ~1.2× bigger, so don't size against those numbers directly.
- Vertical: roughly **−81 to +12.5** (about 94 tall), centered near **−35** (half the cap height of 70.459). Loops/straws may reach about −87.
- Width: 36 (slim bottles) to 62 (with a handle). Margins are the shape's own bounds.
- `actool` rejects the file ("must have a glyph for Regular weight Medium size") unless the Notes group contains `<text id="template-version">Template v.4.0</text>`. `template()` already writes it.

## Design rules

- **Filled silhouettes** in the style of `waterbottle.fill` and `mug.fill`. Details come from cuts (gaps) and holes, never strokes.
- **Same cut width everywhere** in a symbol (`g`). Use straight cuts for flat-front objects, curved (elliptical) cuts and rims for round ones in perspective.
- **Derive multi-panel geometry from one model.** For example, the carton is a single box whose faces are inset from shared edges with `inset()`. Hand-placed offsets produce tapered gaps and floating pieces.
- **Consistent corner radii.** One small radius (~1.5) for joints and panel corners, a larger one for outer silhouette corners. No mix of random sharp and round corners.
- **No overhangs or ledges.** When a loop or handle meets a body, draw them as one outline with fillets at the joint (see `fliplid`, `loopcap`), or overlap it deep into the body.
- Holes are subpaths in reverse winding (`hole()` detects the direction itself, `ellipse_hole()`). A hole may extend into an overlapping filled piece; that area stays filled.
- Rims that meet a slanted side use `rounded_rim()` so the ends don't come to points. Strings and poles use `segment()`.
- **Straws use `straw_path()`**: round caps and a filleted bend, never square ends or a circle stuck on a kink. Keep the straw short (about a quarter of the icon above the body) and start it inside the body so it visibly goes in. Use `flat_start=True` when the hidden end sits in a part too thin to cover a round cap (boba lid).
- **Open vessels show their opening** (elliptical `ellipse_hole` rim), including narrow ones like the flute.
- **Minimum detail sizes** so nothing turns to a hairline at 17pt Ultralight: stems `t * 0.95`, poles and straws `t * 0.7`–`0.9`, dots/bubbles radius about 2.5 at Regular. Prefer fewer, bigger details.
- **Height:** drinks should reach about −80 or higher (about 80+ tall). Only go shorter when shortness is the signature (shot glass), and carry it with shape too. Measure bounds before calling a shape done.
- **No spiky edges:** serrations and spouts get small radii (stick pack teeth 1.4, pitcher spout 4).
- **Cut round shapes** (coconut) model the cut as a real sphere: the opening's back arc meets the outline tangentially, with a rim ellipse open enough (about 0.3 of its width) that its ends don't look pointy.
- Never rename a shipped symbol: drinks store the name as text.
- **Each shape gets one exaggerated signature feature** so similar bottles stay distinct at 17pt.
- **Generic names, no logos.** Shape only (`bottle.loopcap.fill`, not a brand name). Avoid existing system names.
- The app has no dark mode; check previews in light only.
