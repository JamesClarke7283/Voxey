# Fire, burning and fire resistance

Voxey follows the supplied Mineclonia `mods/ENTITIES/mcl_burning/init.lua` and `mods/CORE/mcl_explosions/init.lua`. The implementation is original GDScript using the source as a behaviour reference.

## The three states

The source separates three things that are easy to conflate:

| State | Meaning |
|---|---|
| **Burning** | a creature is alight and takes damage over time |
| **Fire resistance** | an *effect* a player can drink for, which stops burning |
| **`_fire_resistant`** | a *property of a mob kind*, which the source gives to ten mobs |

The third is the one Voxey was missing. Ten source mobs carry `_fire_resistant = true`:

blaze, ender dragon, ghast, hoglin or zoglin, piglin, shulker, wither skeleton, magma cube, strider, wither.

Voxey had **no** general notion of it — a literal `["blaze","ghast","magma_cube"]` list existed inside the campfire-hazard check, which is a different question (whether a campfire hurts a mob) and not the same predicate.

## Why it mattered: the blaze's own fireball

The source's blaze fireball is not a plain projectile. Its `hit_mob` and `hit_player` handlers both do:

    mcl_burning.set_on_fire (target, 5)

So a blaze **sets what it hits alight for five seconds** — which is what makes a blaze dangerous rather than merely damaging. Voxey's fireball dealt fire damage and stopped there, so a blaze was a plain archer in fire colours.

The resistance then matters for a specific, satisfying reason: a blaze hit by *another blaze's* fireball must **not** catch. Without the two halves together, a blaze fight would set both combatants alight, which the source explicitly prevents.

Verified directly: a fireball sets a **zombie** burning (level 1), leaves a **blaze** unlit (level 0), and lights the **player** (level 1).

## Blast fire

The source's `mcl_explosions` takes an `info.fire` flag — off by default, and enabled for exactly two things: a **bed in the Nether** and a respawn anchor. When set, **one destroyed node in three becomes fire** rather than air:

    if fire and math.random(1, 3) == 1 then
        table.insert(fires, npos)

Voxey's blasts had no such flag, and the Nether bed only *refused* with a message. That is the safe outcome but the wrong one: the explosion **is** the punishment for trying, and removing it removes the reason the rule exists. A Nether bed now blasts at strength 5, takes both halves with it, and scorches the ground.

The flag stays opt-in, which is checked: an ordinary blast sets **zero** fires.

## Water as the counter

The source marks four mobs **`_water_sensitive`** — blaze, enderman, snow golem, strider.
Such a mob takes **one damage every half second** while standing in water or out in the
rain, and the rain also **extinguishes** it:

    if (self._water_sensitive or self.burn_time)
        and self:check_timer ("rain_damage", 0.5) then
        if liquidtype == "water" or self:is_exposed_to_rain (node_pos) then
            if self.burn_time then mcl_burning.extinguish (self.object) end
            if self._water_sensitive and self:damage_mob ("environment", 1.0) then
                return true
            end
        end
    end

Voxey had no notion of it, so a blaze could sit in water indefinitely. It is also the
second *separate* fire rule: a blaze is **fire-resistant** (it cannot be set alight) and
**water-sensitive** (water hurts it) at the same time, and neither implies the other. A
magma cube is the opposite pair — fire-resistant but not water-sensitive.

### The flying-mob gap this exposed

Implementing water damage turned up something larger. `ExpeditionCreature` overrides
`_physics_process`, and its flying branch did this:

    if kind in ["ghast","blaze"]: _fly(delta); return

That **return skips `super._physics_process` entirely**, so every shared rule below
it — burning in daylight, water damage, the daylight despawn — never ran for a flying
mob. A blaze could not be put out by rain, and could not be hurt by water, because it
never reached the code that does either.

The weather rules are now one method, `Creature.weather_step`, which the flying branch
calls before handing off to its own movement. The duplication that had accumulated
(two copies of the burning test) is gone with it.

## Floating: most mobs swim, a few sink

The source's `mcl_mobs` defaults to **`floats = 1`** for every mob, and only six kinds
opt out with `floats = 0`: zombie, skeleton, iron golem, piglin, strider and dolphin. A
mob that floats **bobs up** until it is at the waterline rather than sinking:

    if self.floats == 1 and not self.driver and math.random (10) < 8 then
        if depth > LIQUID_JUMP_THRESHOLD or self._liquidtype == "lava" then
            jumping = true
        end
    end

Voxey applied gravity to every mob in water, so a chicken, a cow or a villager dropped
into deep water **sank to the bottom** and stayed there. The rule is now one vertical
branch: a floating mob rises toward the surface and holds there, while the six kinds the
source opts out keep falling.

The split is what makes the rule worth having rather than a blanket "mobs swim": a
chicken crossing a river floats, while a zombie crossing one goes to the bottom. Both
are asserted behaviourally, in separate water columns so one mob's ascent cannot empty
the water the next is measured in.

## Some mobs never despawn

The source's `can_despawn` defaults to **false**, and only twelve mobs opt in. So a
**piglin, a shulker, a villager, an evoker or the wither** is never removed for distance:

    local can_despawn
    if def.can_despawn ~= nil then can_despawn = def.can_despawn else can_despawn = false end

Voxey removed **every** mob past ninety blocks, which silently deleted a boss or a
trader the player had walked away from — including a piglin mid-barter and a wither
mid-fight. The default is now the source's: a mob despawns only if it opts in.

A mob that may not despawn still stops simulating past 220 blocks, so a distant piglin
costs nothing while it waits — the same effect the source reaches by unloading the area
around it.

## The spawn cap counts the neighbourhood

Persisting mobs exposed a second bug, in the opposite direction. Voxey's natural-spawn
cap was twelve, and it counted **every** mob alive:

    for mob in creatures.get_children():
        if mob.kind not in ["end_crystal","ender_dragon","villager","iron_golem"]: normal_count += 1
    if normal_count >= 12: return

A mob past 220 blocks neither loads nor simulates, so counting it is counting something
that costs nothing. Combined with `can_despawn = false`, that made a few stray
**piglins** — which persist forever — block all natural spawning **permanently**.

The cap now counts only mobs within 128 blocks of the player, which is the population
it exists to bound. A crowded neighbourhood still blocks; clearing it lets spawning
resume; distant mobs cost nothing.

## Each mob swings at its own range

The source gives a mob a **`reach`**, defaulting to three, and the spread is wide:

| Mob | reach |
|---|---|
| Wither | 5 |
| Iron golem | 3 (the default) |
| Creeper, enderman, ravager | 3, 3, 2.0 |
| Zombie, skeleton, spider | 2 |

Voxey used one fixed value for **every** mob, so a wither — six hundred health, meant to
be engaged at a distance — swung from about the same place a zombie did. A mob's own
width is added, because the source measures from its collision box rather than its
centre.

## A struck mob runs away

The source's `runaway` is **independent of hostility**, and a **creeper declares it**:

    if self.runaway then self:do_runaway (source) end     -- sets a five-second timer
    runaway = true,
    runaway_from = { "mobs_mc:ocelot", "mobs_mc:cat", },

Voxey fled only with a *passive* mob (`if not hostile: scared = 5`) **and** only when the
mob was not already chasing — so a struck creeper kept advancing, which is the opposite
of the source. A creeper that backs off when hit is a different fight: you can drive one
away with a bow instead of only trading blows.

Two changes were needed, and the second is the one that mattered: the flag now defaults
to the mob's passivity (so a cow still flees without declaring anything), and the flee
**overrides the chase** rather than sitting below it in the branch chain. Ordering alone
was not enough — a chasing creeper would have overwritten the flee direction on the next
line.

`runaway_from` narrows the trigger to specific attackers (a creeper runs from an ocelot
or a cat); Voxey keys the flee on being hit at all, which is the wider reading and is
recorded as a gap.

## A kill pays the mob's own experience

The source gives every mob an `xp_min`/`xp_max`, and the spread is wide:

| Mob | XP |
|---|---|
| Wither | **50** |
| Blaze | 10 |
| Skeleton | 6 |
| Zombie, creeper, enderman, spider, ghast, shulker | 5 |
| Slime, magma cube | 4 |
| Cow, pig, chicken, sheep, fish | 1 |

Voxey paid a **flat two** for any hostile mob and one for anything else, so a wither —
six hundred health, a fight in its own right — was worth exactly what a zombie was.
A kill now pays the mob's own value, and the source's default is **zero**: a mob that
declares nothing is worth nothing, which the old flat award was guessing at.

Two further details came out of aligning this:

- **A slime is the exception.** The source registers three sizes worth four, two and
  one, and a big slime *splits* on death. Its reward comes from its size rather than a
  fixed number, and Voxey's three sizes already paid 4 / 2 / 1.
- **A kill was paying twice.** Unlocking an achievement added a default two experience,
  so a zombie — whose achievement is the only one an ordinary kill fires — paid seven
  instead of five. The source pays experience only where an achievement declares
  `reward_xp` (five of its achievements do), so the implicit default is gone.

## Per-group armor

The source's `armor` is the percentage of a group's damage a mob **takes** — not a
resistance:

    damage = damage + (tool_capabilities.damage_groups[group] or 0)
        * tmp * ((armor[group] or 0) / 100.0)

So `{undead = 90, fleshy = 90}` takes ninety percent of either, and a group the table
**omits deals nothing at all**. A plain number is shorthand for `{fleshy = <number>}`:

    if type(self.armor) == "table" then armor = table.copy(self.armor)
    else: armor = {immortal = 1, fleshy = self.armor} end

Voxey applied a single flat resistance, which could not express "takes ten percent less
from an ordinary blow" at all. Measured now: a ten-damage blow costs a **zombie 9.0**
and a **spider 10.0**, and only a **blaze** accepts a snowball.

### Enchantment bonuses carry a group too

The source's enchantments are `increase_damage(group, factor)` — Sharpness adds
`fleshy`, Smite `undead` and Bane of Arthropods `arthropod`. Because a bonus carries a
group, the target's armor scales **it** as well:

| Blow | On a wither (`undead = 80`) |
|---|---|
| Ten points of sword | 10 |
| Plus ten points of Smite | **+8** |
| Total | 18 |

Voxey added the bonuses as flat damage, so a Smite bonus was worth its full amount
against a mob that resists Smite. The bonuses now accumulate per group and are scaled by
each group's own factor. Against a zombie (`undead = 90`) Smite V adds eleven and a
quarter rather than twelve and a half, which is the number a player actually deals.

### Only melee consults the table

The table is read on the source's **punch** path. Everything it routes through
`mcl_damage` instead — lightning, arrows, fireballs, magic, freezing, the environment —
is a damage *type* and is not scaled by it. Getting this wrong is easy and silent: my
first version scaled everything, which quietly reduced lightning strikes, arrow hits and
potion damage on any mob with a non-100 entry. Three checks caught the three cases.

## Recorded source gaps

- **No respawn anchor.** The source's other `fire = true` explosion comes from a respawn anchor, which Voxey does not have as a block.
- **No ray-traced occlusion.** The source traces rays outward and lets intervening rock shield a blast, so a wall between you and the explosion protects you. Voxey's blast is a radius test against distance, so cover does not help.
- **No `set_on_fire` node group.** The source lets a node ignite a creature that touches it (`group:set_on_fire`), which is how lava and fire behave uniformly. Voxey handles fire and lava damage directly instead, without the shared group.
- **No fire damage to mobs from standing in fire.** Burning is applied to mobs by effects, but a mob standing in a flame node is not ignited by it the way the source's globalstep does.
