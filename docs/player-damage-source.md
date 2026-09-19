# Player damage and the void

Voxey's player takes damage from the same sources Mineclonia's does. Most were already in place; the void was not, and its fix uncovered a second bug.

## The void

The source's `mcl_void_damage` deals **four health every half second** below the world:

    local VOID_DAMAGE_FREQ = 0.5
    local VOID_DAMAGE = 4

It is a *rate*, not a killing blow. That distinction matters: a player who falls off the End's islands has a couple of seconds of falling during which the damage ticks, and can sometimes be pulled back out. A flat killing blow removes that.

### Two bugs in one line

The original code was

    if position.y < game.world.generator.min_y()-5: hurt(20,true,Vector3.INF,"void")

which was wrong twice:

1. **One killing blow instead of a rate.** Twenty damage kills a full-health player outright, where the source would have spent five seconds doing it.
2. **It never ran at all.** The line sat *below* this guard at the top of `_physics_process`:

        if not game.world.loaded_at(position): return

    The void is below `min_y`, so `loaded_at` is false there — the function returned before reaching the check. The whole branch was **unreachable**, and the void did nothing.

The fix moves the void test *above* the guard, which is where it has to be: the void is by definition outside the loaded world, so any check placed after a "is this loaded" guard can never fire.

The timer is the source's own: damage in discrete ticks 0.5 seconds apart, reset on leaving the void, rather than continuous per-frame subtraction.

### Why `hurt` already knew about the void

`Player.hurt` had a `cause == "void"` path from the start — void damage bypasses armor, resistance and absorption. That handling was correct and simply never reached. The checks now assert the rate (four per tick, twice), that leaving stops it, and that the timer clears.

## What the void still does not do

- **No respawn-to-spawn fallback.** The source teleports a player back to spawn instead of damaging them when damage is disabled or the player is immortal. Voxey's creative mode already ignores damage, so the outcome matches; there is no explicit teleport.
- **No entity cleanup.** The source also removes *entities* that fall into the void, by wrapping every entity's `on_step`. Voxey's creatures despawn on distance rather than depth, which reaches the same result in practice but is not the same rule.
