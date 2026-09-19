# Swimming controls and shoreline escape

Hold **Space** to swim upward and **Shift** to swim downward. Move toward the shore while holding Space to climb onto a bank up to one block above the water surface. Shift keeps sprinting on dry land and descending during creative flight. If both swimming controls are held, descent takes precedence. On touch devices, hold Jump to rise; the Sneak toggle descends.

The previous controller tested water at waist height and switched to land gravity before the feet left the surface. Its shore boost required empty space in the bank itself, so colliding with a bank disabled the boost. Swimming now samples foot immersion and checks space above a nearby bank in the actual direction of movement. A normal collision-resolved jump carries the player onto the shore; solid ceilings and tall walls remain impassable. Flowing-water heights and submerged kelp are included.

Touch Jump now stays held until release. Its former quarter-second timer prevented continuous swimming. Creative double-tap flight is preserved.

`tests/swimming_checks.gd` drives actual physical keyboard input and touch-control state through the player controller. It covers ascent, Shift descent, shallow immersion, competing controls, sprint separation, source/flowing/kelp water, full-block shorelines at 60 and 20 FPS, solid ceilings and tall walls. `tests/swimming_tour.gd` captures underwater, surface, shore and diving views for visual inspection.
