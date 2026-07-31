# LGD Character Animation Review v2

Status: final direction and timing review. These boards intentionally retain a
dark review background so posing is easy to compare. They are not yet the
transparent, grid-cropped production sheets consumed by Godot.

## Shared frame map

Each character board contains exactly 22 poses:

1. Row 1 — four idle frames.
2. Row 2 — six front-facing vertical movement frames, reused for both up and
   down movement as requested.
3. Row 3 — six left-facing movement frames.
4. Row 4 — six right-facing movement frames.

The six-frame locomotion rhythm is `contact -> down -> passing -> up -> opposite
contact -> passing`. Production timing should begin around 8–10 FPS for Hana
and 10–12 FPS for Glider and the helper mouse, then be tuned in context.

## Character-specific motion

### Hana

- Idle motion stays in the blink, breathing height, hair tips, and dress hem.
- Walking keeps the head stable and alternates feet and arms cleanly.
- Side profiles preserve hair length, dress volume, and the floral hem pattern.

### Glider

- Glider is a sugar glider, not an owl: gray fur, cream muzzle/belly, large dark
  eyes, rounded ears, dark forehead stripe, folded patagium, and fluffy tail.
- Idle secondary motion uses a blink, ear twitch, and tail curl.
- Scampering uses small paw changes, gentle compression, and tail counter-swing.

### Helper mouse

- The helper is a cream mouse with pink features, sage scarf, and walnut pouch.
- Idle secondary motion uses sniffing, blinking, an ear twitch, and tail curl.
- Scarf and pouch remain attached consistently; the scarf tip bounces during
  movement while the tail counter-swings.

## Production invariants

- Pin the ground baseline and main body axis across frames.
- Keep lighting from the upper left in every pose.
- Use hard pixel clusters with no antialiasing or smooth resampling.
- Left and right rows must remain strict directional counterparts.
- Rebuild at the exact Godot frame grids rather than downscaling these boards.
- Preserve the existing collision footprints unless playtesting justifies a
  separate gameplay change.

## Final prompt set

The boards were created with the built-in image-generation workflow using the
existing LGD art and v1 review board as visual references.

### Hana prompt

Preserve Hana's aubergine hair, cream floral-hem dress, gold collar accent, and
gentle expression. Create exactly 4 idle, 6 front-facing vertical, 6 left, and
6 right crisp pixel poses. Keep the baseline, identity, costume, lighting, and
body volume stable; use subtle breathing and hair/hem secondary motion.

### Glider prompt

Replace the incorrect owl concept with an original cute sugar glider with large
dark eyes, rounded ears, forehead stripe, cream belly, folded patagium, and a
long fluffy tail. Create exactly 4 idle, 6 front-facing vertical, 6 left, and 6
right poses. Prohibit all beaks, feathers, wings, talons, and mixed directions.

### Helper mouse prompt

Preserve the cream helper mouse, pink ears/nose/paws/tail, sage scarf, and brown
pouch. Create exactly 4 idle, 6 front-facing vertical, 6 left, and 6 right poses.
Use a sniff/ear-twitch idle, alternating-paw scamper, scarf bounce, and tail
counter-swing while keeping accessories and anatomy consistent.

The final Glider review board includes a deterministic horizontal-mirror cleanup
of the final two left-facing cells after generation; no other board content was
changed during post-processing.
