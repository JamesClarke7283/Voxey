# Villager trade lifecycle

The installed Mineclonia checkout supplies the behavioral reference:
`mods/ENTITIES/mobs_mc/villager.lua`, the enchanting engine and definitions,
and `mcl_armor/register.lua`. `VillagerTrading` implements offer generation,
promotion, restock state and migration in original GDScript. See
[Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

New villagers generate only their current unlocked tiers. Promotion appends all
of the next tier's offers while preserving the earlier offers, their chosen
prices, metadata, stock and demand. The source enables every offer in a tier;
it does not choose two. All 297 table rows across thirteen professions match
the installed source. Two old shepherd mappings were corrected: the source
buys grey and green dye where Voxey previously accepted light grey and lime.

Counts draw in source order: first payment, optional second payment, output.
Enchanted equipment then draws a power from 5 through 19 and uses the existing
reliable enchanting engine, with the actual registered enchanted item's
eligibility profile. Books uniformly select one eligible enchantment and then
its level. The exported source profiles matter: the installed source's manual
Curse of Binding registration does not mark it tradable, and its enchanted
chestplate does not have the group required for random Thorns selection.
The trade path respects those registrations; it does not retrofit existing
player-owned equipment. The later [shared registry audit](enchanting-registry-source.md) now applies
the same completed registrations across table selection and anvil eligibility.

The source uses a process-wide random generator. Voxey uses a saved per-villager
32-bit stream seeded from world seed and villager identity. This is a deliberate
random-sequence adaptation; controlled identical streams match the source
counts and enchantments. The saved stream advances when a tier is generated.
Older saves already rolled locked tiers in advance; migration preserves those
exact offers in a future-offer list and releases them when their tier unlocks.

The XP thresholds remain 0, 10, 70, 150 and 250. A qualifying trade starts or
restarts a two-second timer and awards five additional player XP immediately,
on top of the normal 4–6 trade XP. Every qualifying trade grants that bonus,
even while another promotion is pending. Timer expiry advances exactly one tier
and grants Regeneration I for ten seconds. A large XP balance does not trigger
several promotions without further trades. Master has no further promotion.
The timer runs while the trading panel is open; new offers and the badge update
there. Pending time, generated offers, RNG position and active regeneration
survive a world reload. Infection preserves exported trade identity but discards
the pending promotion and active effects, which are absent from the source export.

A first workstation check starts the restock clock. Used trades consume one of
two restocks, update every active offer's demand by `2 * uses - stock`, and reset
uses. A second restock requires **more than** 120 seconds. Crossing a day boundary
or 600 seconds starts a new working day: each unused old restock is caught up,
then the allowance is reset to two. That branch returns immediately. If the old
allowance was zero, used offers therefore remain used until the next workstation
check. The farmer workstation and other professions share this state machine.

A source quirk corrects an earlier assumption about price caching. Its open
traders table is keyed by player objects, so `table.getn` reports zero; the guard
in `show_trade_formspec` does not suppress subsequent price applications.
Completed trade callbacks and promotion refreshes therefore reapply reputation
and Hero prices. Merely calling the lower-level transaction routine leaves the
current quote intact until that UI refresh. [Gossip and price arithmetic](villager-gossip-source.md)
remain in their own module.

Wandering traders use the shared payment UI but the source's separate behavior:
no player XP reward, no villager XP or gossip, no tier promotion, and no Hero
price adjustment. These exclusions also apply to older saved wandering offers
that lack the new explicit reward flag.

## Verification

`tools/export_villager_trading_reference.py` runs actual Lua callbacks in Luanti:
297 catalog rows, 1,311 generated offers, 2,430 restock states, 1,000 promotion
states, and 65 tier-activation cases. A further callback check verifies the
object-keyed price-refresh guard: **5,104 source checks** total. The fixture
records four source hashes and exports the registered trade enchantment profiles
separately as runtime data.

`tests/villager_trading_checks.gd` exercises real purchases, open-panel promotion,
XP orbs, regeneration, restocks, legacy offers, save/reload and infection. The
wandering-trader suite checks its reward and pricing exclusions. Village,
enchanting, gossip, farmer and alchemy suites provide regressions. The native
payment interface and per-villager RNG remain adaptations; full schedules,
individual sleep and navigation remain open work toward complete parity.

Validation on 2026-10-24: all 5,104 source checks pass and all four hashes match
the installed checkout. The combined trade/gossip/zombie/farmer run passes 143
checks; the later trade/gossip/trader run passes 79, and the final reward and
promotion run passes 50. Village regressions pass 904, alchemy passes 239, and
the existing enchanting reference suite reports zero failures. The rendered
Novice and Apprentice screens were inspected. Wandering traders now omit the
inapplicable level, XP and restock displays. Linux pack export succeeds.
