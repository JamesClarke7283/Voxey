# Banners

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_banners/{init,items,patterncraft}.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## Layers are the whole point

A banner is a coloured flag carrying an ordered list of **layers**, each a pattern plus the dye colour it was applied in. The source stores that list in the banner's metadata and rebuilds both the description and the texture from it. Voxey already had the sixteen coloured banner blocks and their recipes; this adds the layer system.

## The pattern table — 42 entries

The source's `patterncraft.lua` table is transcribed in full:

- **32 dye-grid patterns.** Each is a three-by-three grid of dye (`d`) or empty (`e`) cells, crafted in a table. Every one of the 32 grids was verified cell-by-cell against the source rather than typed from memory — that check caught three transcription errors (`square_bottom_right`, `stripe_bottom` and `gradient_up`) before they shipped.
- **10 special patterns.** Each is crafted shapelessly from paper plus a specific item:

| Pattern | Item |
|---|---|
| Thing | enchanted golden apple |
| Skull Charge | wither skeleton skull |
| Creeper Charge | creeper head |
| Flower Charge | oxeye daisy |
| Bricks | brick block |
| Bordure Indented | vine |
| Globe, Piglin, Guster, Flow | their own pattern items |

## Emblazoning

- Applying a pattern **appends** a layer; it never replaces one.
- A banner carries at most **`max_craftable_layers` = 6**.
- A banner used on an emblazoned banner **combines** the two, appending the other's layers in order. Combining a banner with identical emblazoning is refused, which the source also declines to do.
- The description lists the layers with their colour and pattern names, as the source's `update_description` does.

## Art

An emblazoned banner's icon is drawn by painting each layer's own grid over the base colour, so two different patterns render visibly differently. This mirrors what the source's texture builder composes from its pattern textures.

## Recorded source gaps

- **No loom.** The reference provides a loom block where a banner, a dye and an optional pattern item are combined through a formspec. Voxey applies a pattern by using a dye or pattern item on a placed banner, which reaches the same layer list without the loom UI.
- **No cauldron washing.** The source lets a water cauldron strip a banner's topmost layer. Voxey's cauldrons do not yet accept banners.
- **Texture layering is procedural.** The source composites real pattern textures with masks; Voxey paints each layer's grid, so the icon shows the right *shape* per pattern but not the source's exact texture art.
- **The `thing` pattern's item is the ordinary golden apple.** Voxey registers the enchanted golden apple under the same id, so the distinction the source draws between them does not exist here.
- The source's `mcl_offhand` banner-shield interaction and its banner-on-wall/ceiling placement variants are not implemented.
