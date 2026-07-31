# LGD Cozy Pixel Direction v1

Status: review direction only. The PNG boards in this folder are visual targets,
not production-ready sprite sheets. Live game assets remain unchanged until the
direction is approved and redrawn on their exact transparent frame grids. The
owl-like Glider shown in `characters_review.png` is superseded by the sugar
glider design in `../lgd_cozy_pixel_v2_animation/glider_animation_review.png`.

## Design intent

Keep LGD immediately readable and modest in scope while giving every sprite a
warmer, more authored finish. The direction uses cozy storybook pixel-art traits:
compact silhouettes, warm materials, clustered foliage, and restrained fantasy
detail. It is original to LGD and must not reproduce recognizable characters,
props, layouts, or exact palettes from another game.

The target is **simple forms with selective detail**, not uniformly dense art.
Important gameplay silhouettes should read before surface texture does.

## Visual pillars

1. **Soft shapes, crisp pixels** — rounded major forms built from deliberate
   stepped contours; no antialiasing or blurred resampling.
2. **Clustered detail** — highlights, folds, bark, leaves, and stone facets use
   connected pixel clusters. Avoid isolated noise pixels except for seeds,
   sparkles, or similarly tiny subjects.
3. **Warm shared light** — light comes from the upper left. Highlights lean
   cream or honey; shadows lean plum or cool charcoal.
4. **Material clarity** — wood has sparse lengthwise grain, stone uses broad
   planar facets, cloth uses only a few folds, and foliage uses overlapping
   clumps rather than stippling.
5. **Quiet animation** — motion is small and characterful. Anchors stay fixed;
   secondary motion belongs in hair, hems, ears, leaves, or loose seeds.

## Core palette

These colors are the shared starting palette, not a requirement to use every
swatch in every sprite.

| Role | Hex |
| --- | --- |
| Deep plum outline | `#241722` |
| Plum interior shadow | `#432C3B` |
| Warm cream | `#F0E2C9` |
| Cream highlight | `#FFF0D1` |
| Walnut shadow | `#5A3429` |
| Walnut midtone | `#965B39` |
| Honey highlight | `#D58B4A` |
| Sage shadow | `#4F5A3D` |
| Sage midtone | `#7F8954` |
| Sage highlight | `#B1B56C` |
| Coral shadow | `#A84F50` |
| Coral midtone | `#DC7468` |
| Butter yellow | `#E7BC43` |
| Stone shadow | `#56535C` |
| Stone midtone | `#8C8790` |
| Stone highlight | `#C9C3B9` |

Use three to five colors per material. Reserve the brightest color for small
focal accents; do not outline every internal edge.

## Production grids and invariants

| Asset | Existing grid to preserve | Direction |
| --- | --- | --- |
| Hana idle | 4 horizontal frames, `64x64` each | Feet and body axis fixed; at most 1 px vertical breathing motion; hair and hem provide the loop. |
| Glider | `32x64` | Cute sugar glider: large dark eyes, rounded ears, forehead stripe, cream belly, folded patagium, and a long fluffy tail. Never use owl or bird anatomy. |
| Rat assistant | `32x32` | Low horizontal silhouette; large ear and tail create recognition; held items remain readable above it. |
| Tree | 3 horizontal frames, `32x64` each | Seedling, sapling, mature; ground point remains fixed while canopy mass grows. |
| Mushroom | 3 horizontal frames, `32x32` each | Spores/buds, small cap, mature cap; keep coral cap as the focal hue. |
| Dandelion | 3 horizontal frames, `32x32` each | Sprout, yellow bloom, white seed head; seed detail must remain clustered. |
| Mushroom house | `32x32` | Oversized cap and arched door; fence and chimney are secondary accents only. |
| Barrel | `32x32` | Strong oval top and vertical stave rhythm; avoid tiny hardware noise. |
| Stone deposit | `64x32` | Broad base and three-to-five major facets; preserve collision footprint. |
| Processor | layered `32x32` base/arms/stone | Opposing arms and center stone must remain separable for the existing squash/press animation. |
| Inventory icons | `16x16` or `32x32` source canvas | One dominant silhouette, two or three interior cues, consistent visual weight. |
| Grass | `32x32` tile | Low-contrast clustered blades; edges must tile without a visible seam. |

Keep the current Godot nearest-neighbor import behavior. Draw at 1x scale; do
not create a large painted asset and downsample it. Transparent padding and
frame registration are part of the asset contract.

## Animation rules

- Pin feet, ground contact, and the main body axis across frames.
- Prefer one-pixel changes at production resolution.
- Preserve volume: a squash should widen as it shortens.
- Idle loops should read as `neutral -> settle -> neutral -> rise`.
- Do not change facial identity or lighting direction between frames.
- Test at native resolution and at the game's integer display scale.
- Processor layers must overlap cleanly through the existing scale and
  position tracks; no baked arm or stone motion in the base layer.

## Review-board prompt set

All boards used the built-in image generation workflow with existing LGD PNGs
as edit references and the `style-transfer` use case.

### Characters

Redesign Hana's four-frame idle strip, Glider, and the rat assistant as original
cozy-storybook pixel sprites. Preserve identities, frame count, stable animation
registration, simple silhouettes, hard pixel edges, and small-scale readability.
Use warm cream, aubergine, sage, coral, and gold accents; add selective fabric,
hair, feather, and accessory clusters; copy no recognizable external game asset.

### Flora

Redesign the tree, mushroom, and dandelion as exactly three left-to-right growth
stages, plus a grass swatch. Preserve growth meaning and ground registration.
Use clustered foliage, bark knots, cap/gill cues, petals and seed filaments with
crisp pixels and restrained sage, walnut, coral, yellow, and ivory ramps.

### World props

Redesign the mushroom house, barrel, stone deposit, and compact processor as
four separated world sprites. Preserve gameplay functions and silhouettes.
Emphasize material clarity and keep the processor suitable for separate
base/arms/stone layers.

### Inventory items

Redesign the acorn, bundled wood, mushroom, stone, and dandelion tuft as exactly
five consistent icons. Preserve strong silhouettes at `16x16` to `32x32`, use
only two or three interior material cues, and avoid emoji styling or clutter.

## Approval checklist

- Hana's increased character scale and facial detail still feel appropriate for
  LGD's world scale.
- The muted sage/coral/cream palette is the desired baseline.
- Props should retain this amount of construction detail after reduction to
  their production grids.
- Mature plants may intentionally exceed the visual mass of the current art,
  provided collision shapes and ground anchors remain unchanged.
- The rat's scarf/pouch and the mushroom house's fence/chimney are accepted as
  recurring world-building motifs, or removed before production.
