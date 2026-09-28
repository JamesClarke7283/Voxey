# Death messages and the damage-flag audit

Voxey follows `HUD/mcl_death_messages/init.lua` and `CORE/mcl_damage/init.lua` in the
supplied Mineclonia checkout. The implementation is original GDScript using the
source as a behavioural reference.

## What was missing

The death screen printed one static line. Every death read "A new beginning." no
matter what killed the player, and the reason each `hurt()` passed was used only to
pick a flag or two.

## The table

All 31 source messages are transcribed in the source's own order, with the killer
and item variants the source declares — `@1` is the victim, `@2` the killer and
`@3` the item, which the source brackets (`:151`). `message(reason, killer, item)`
follows the source's dispatch order (`:198-203`): killer, then item, then plain,
then the fallback. Two entries declare `escape` rather than `assist` (a wither and
an anvil), which is preserved.

The source's **assist** step is out of reach: it needs the source's five-second
per-object assist cache, and Voxey's `hurt` carries the attacker as a position
rather than an object. That is recorded rather than faked.

## The flag table

`mcl_damage.types` is transcribed in full — all six mitigation flags per reason,
plus the five the audit reports but does not use (`is_magic`, `is_lightning`,
`bypasses_guardian`, `bypasses_invulnerability`, `scales`,
`always_affects_dragons`). `flags(reason)` is the module's whole point: it is now the
one place that says what a reason does, and `Totems.bypasses` reads
`bypasses_totem` from it instead of keeping a second list that could drift.

## What the audit found

`audit(voxey_causes)` compares the flags each Voxey cause *actually* implements
against the source's declaration. Four real divergences came out of it, and they are
recorded rather than silently reconciled:

| Divergence | Detail |
|---|---|
| Armor bypass implies totem bypass | `player.gd` skips `Totems.intercept` when `bypass_armor` is set, so `starve`, `fall`, `in_wall`, `freeze` and `hot_floor` all bypass a totem. The source sets `bypasses_totem` for `out_of_world` alone. |
| The default cause | The source's `generic` bypasses armor; Voxey's default does not. |
| Magic | The source's `magic` bypasses armor; Voxey's magic is armor-reduced. |
| `hot_floor` | The source marks it `is_fire`; Voxey's magma-block damage is not classified as fire. |

The causes that already agree are `void`, `sweet_berry`, `explosion`, `mob`,
`projectile`, `anvil` and `falling_node`.

## One deliberate departure

The source's last resort (`:180-182`) is its **translation key** plus the victim's
name, because every other string in that file goes through the engine's translator.
Voxey has no translator, so that key would print literally on the death screen:

```
mcl_death_messages.messages.arrow The player
```

The keys are kept so the shape matches the source, and an unknown reason still
produces one — but a cause with only a killer form, asked for without a killer,
names the cause in prose instead (`The player was shot`). Five aliases connect
Voxey's cause names to the source's reasons: `void` → `out_of_world`, `projectile` →
`arrow`, `charged_explosion` → `explosion`, and `fire`/`lightning` → `in_fire` and
`lightning_bolt`. A check walks all 28 causes Voxey's call sites actually pass and
asserts every one renders prose.

## Verification

`tests/death_message_checks.gd` (317 checks) covers the table (every reason has a
non-empty message with no unfilled placeholder, the plain forms open with the
victim, the killer-only forms name the cause in prose), the flags for the reasons
with the most distinctive behaviour (`in_wall`, `out_of_world` with
`bypasses_totem`, `starve` with `bypasses_magic`, `arrow` with `is_projectile`), the
aliases, the audit's four mismatches, and the readability of every cause in use.
