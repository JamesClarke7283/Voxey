# Note blocks

Voxey ports the local Mineclonia `mods/ITEMS/REDSTONE/mcl_noteblock/init.lua` behavior through `scripts/note_blocks.gd`. The source file SHA-256 is `07d2d4899e8826dec9de489c1028ad9b75344b500457739aec5d2e5af17c8f62`; the supplied source directory has no Git revision metadata.

Craft one note block from eight planks around redstone dust at a crafting table. Mixed classic wood species work. Place it above the instrument material, leave literal air above it, and right-click to advance one semitone through 25 notes. The initial mining stroke plays the current note without changing it; continued mining still breaks the block. Sneaking bypasses tuning, allowing normal block placement. Both keyboard and touch use the same interaction path.

Redstone plays only on a rising edge. A blocked rising edge is consumed, and uncovering an already powered block does not play a delayed note. Pitch and powered state live in ordinary saved block metadata, including piston movement. Breaking drops a plain note block; placing that item starts at note zero. The full cube also conducts strong power into neighboring dust, rather than becoming electrically insulating merely because it is tracked as a circuit device. Source hardness is 0.8, axes are preferred, and furnace fuel time is 15 seconds.

## Instruments and pitch

Exact block matches take priority over source material groups. This distinction matters: a gold pressure plate is not a gold block, ordinary/blue ice is not packed ice, and a carpet is not wool.

| Block immediately below | Instrument |
| --- | --- |
| Gold block | Bell |
| Clay | Flute |
| Packed ice | Chime |
| Bone block, any axis | Wooden xylophone |
| Iron block | Iron xylophone |
| Soul sand | Cow bell |
| Emerald block | Square wave |
| Hay bale | Banjo |
| Glowstone | Electric piano |
| Wool, including dyed wool | Guitar |
| Pumpkin, including the existing carved-pumpkin alias | Didgeridoo |
| Glass or glass pane | Sticks |
| Source `material_wood` group | Bass guitar |
| Source `material_sand` group, including gravel | Snare |
| Source `material_stone` group | Bass drum |
| Everything else | Piano |

Wood groups include the six classic log/plank families, their wooden building shapes/fences/gates/doors/trapdoors, source wooden workstations, the jukebox, wooden buttons and pressure plates. Stone includes stone building shapes, Nether-brick barriers, source stone workstations and stone/blackstone input devices. Weighted pressure plates, leaves, beds, signs, lecterns, carpets and ordinary ice use the piano because their source definitions do not carry one of these material groups. A shape inherits its source material group, not the exact-node special instrument of its ingredient.

All 16 musical instruments are obtainable with the current inventory. [Packed ice and bone blocks](dense-materials-source.md) close the chime/xylophone material dependencies. The source also allows a resin block as an alternate flute base; that material is not present. Decorative mob heads above a note block can override the instrument with an unpitched mob sound in Mineclonia. Voxey has no corresponding obtainable head blocks, so this head override remains a dependency gap; ordinary non-air blocks above the instrument silence it.

The pitch multiplier is exactly `2^((note - 12) / 12)` for indices 0–24. The source piano uses 24 distinct recordings for 25 notes, reusing the final recording one semitone higher; Voxey uses a synthesized C5 base and the same semitone multiplier, producing the source piano register C4–C6. The other voices preserve the source two-octave transposition behavior. Colored rising note glyphs use the source color interpolation and floor rounding, including the last green/blue step. Audio uses the existing spatial voice pool with a 48-block maximum range and respects the game audio setting.

## Original audio and art

`scripts/note_block_tones.gd` creates deterministic original additive/percussive waveforms. `tools/generate_note_tones.gd` renders the 16 mono 22,050 Hz PCM16 WAVs in `assets/audio/noteblocks/`. Runtime playback loads and caches those files, avoiding synthesis on the first redstone tick. The committed WAV import settings preserve PCM16 instead of Godot's default lossy compression. The fallback generator keeps development usable if an asset is deliberately removed.

These timbres are an adaptation, not copies of Mineclonia's recordings. The waveform equations, audio data and procedural speaker-grid texture are original Voxey work; no source sound or texture file was copied. The gameplay port follows Mineclonia's GPL-3.0-or-later source licensing. Regenerate audio with `godot --headless --path PROJECT --script res://tools/generate_note_tones.gd`, followed by an editor import.

## Verification

`tests/note_block_checks.gd` exercises mixed-plank recipe transactions, all obtainable instruments and important negative material matches, all 25 pitches/colors, audible/distinct/cached waveform data, real tune/punch input, touch-sneak bypass, air gating, actual redstone edges and through-cube conduction, piston metadata, break/replacement and full save/reload without a spurious rising-edge sound. Run through `tests/lifecycle_runner.gd -- note_block` after a fresh import of the WAV assets. Rendered/audio listening checks are distinct from these deterministic headless assertions.
