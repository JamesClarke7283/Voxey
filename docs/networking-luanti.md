# Multiplayer networking and Luanti adaptations

The GDScript networking helpers adapt these files from the user's Luanti checkout
at commit `32bb549cff23249c11c6be301d0c2270caaab627`:

- `scripts/network_motion.gd`: `SmoothTranslator::init`, `update`, and `translate`
  from `src/client/content_cao.cpp`, with yaw in radians and a teleport reset.
  Upstream copyright: 2010–2013 celeron55, Perttu Ahola and contributors.
- `scripts/network_block_sync.gd`: the sent/sending invalidation and acknowledgement
  rules from `RemoteClient::GotBlock`, `SentBlock`, and `SetBlockNotSent` in
  `src/server/clientiface.cpp`. Voxey adds revision numbers, transfer tokens and
  timeouts so delayed acknowledgements cannot hide newer edits.
  Upstream copyright: 2010–2014 celeron55, Perttu Ahola and contributors.

Both adaptations retain LGPL-2.1-or-later licensing. The license is supplied in
`LICENSES/LGPL-2.1-or-later.txt`; the corresponding adapted source is included in
this repository. Upstream source: <https://github.com/luanti-org/luanti>.
The Android, Linux and Windows export presets include the license and this
attribution file as non-resource files.

Voxey continues to use Godot's ENet transport. These adaptations do not implement
Luanti's wire protocol or provide compatibility with Luanti clients or servers.

## Synchronization

Protocol 4 separates traffic across six Godot RPC channels:

| Channel | Traffic | Delivery |
| --- | --- | --- |
| 0 | Join, settings, block edits and node interactions | Reliable |
| 1 | Player positions and roster, 20 Hz | Unreliable ordered |
| 2 | Inventories, mining transactions and storage replies | Reliable |
| 3 | Changed station/circuit state, creature/item lifetimes and metadata | Reliable |
| 4 | Compact creature/item motion batches, 10 Hz | Unreliable, per-entity sequences |
| 5 | Background column reconciliation and acknowledgements | Reliable |

Guests acknowledge loading before the host begins the independent snapshot
streams. Player and entity snapshots have monotonic sequences, and remote motion
is interpolated every rendered frame. Extrapolation is limited to half an update
step; teleports reset the interpolator. The host owns entity physics and pickups.
Appearance is sent reliably when it changes. Motion packets omit appearance and
item metadata and limit entity batches to twelve transforms, avoiding fragmented
unreliable packets even with a full player roster or many creatures. Losing one
motion batch cannot undo another entity's newer position or remove a creature.

Live edits are coalesced and sent in batches of at most 128 cells, up to two
batches per network tick. Background repair allows two columns in flight per
guest and at most one batch per column per tick. New edits invalidate old column
acknowledgements. An audit every three seconds permits repair of divergent local
predictions without broadcasting every edited cell in the world at once.

Station updates contain changes and explicit deletions. Each storage transaction
has a world-state sequence so an older snapshot on a different channel cannot
restore its previous contents. Actions carrying inventory snapshots share one
ordered channel and rejected stale actions receive the authoritative inventory.
Queued mining accepts its tool snapshot before waiting for terrain generation.
Full metadata checkpoints every three seconds also repair rejected client-only
predictions when the host's authoritative state has not changed. Unchanged
circuit visuals are left alone during these checkpoints.

## Validation

Run `./tests/run_network_tests.sh`. It includes interpolation, loss and delayed
acknowledgement checks, then launches independent ENet host/guest processes for
inventory, reconnect, block visibility, joining, rejection and distant-streaming
regressions. `--inventory` and `--world-sync` select an integration group; both
also run the protocol checks. To run through the loopback UDP impairment relay:

```sh
VOXEY_TEST_PROXY=1 ./tests/run_network_tests.sh
```

The relay introduces 25–75 ms delay in each direction, jitter, 4% packet loss and
occasional duplicate packets. The protocol tests also simulate stale samples and
reordered acknowledgements. These tests do not emulate all real-world network
conditions.
