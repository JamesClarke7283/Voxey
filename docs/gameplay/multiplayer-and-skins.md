# Multiplayer and character appearance

## Host and join

From the title screen, choose **Multiplayer**, select a saved singleplayer world under **World to host**, then click **Host selected world**. The world loads with its saved inventory, buildings, game mode, and rules before hosting starts. You can also open **Multiplayer** from the Escape menu to **Host this world**, or select another saved world to host; the current world is saved before switching. The server listens on **0.0.0.0**, using **UDP port 24570** by default, and supports up to **16 players** including the host. You can change the port before hosting.

The **Escape menu** shows your computer's **local IP address** while hosting. Its single **Copy IP** button copies the complete join address, including the port (`IP:port`). If your computer has several network adapters, select the appropriate address in the Multiplayer screen before copying. Share this local address with players on your LAN. `0.0.0.0` is the listening address; guests use the displayed local address to connect.

Other players choose **Multiplayer** on the title screen, paste the host's IP or `IP:port`, and click **Join server**. For players outside your LAN, forward the selected UDP port to the host and share your public address. Connection failures and occupied ports are shown in the multiplayer screen. Disconnect there or return to the title screen to close the session.

The host owns the world. Players share block edits, redstone and steam machinery, chests, item pickups, and creature state. Shared-storage clicks are processed by the host. Returning guests retain their main backpack when reconnecting to a running server, and it is included in the host's world saves. Character appearance and player movement are visible to everyone.

A session shares the host's current dimension. Disconnect before changing dimensions. Creature simulation runs on the host; existing creature AI chooses its host player as the main target.

Hold **Tab** during play to list connected players, with your own name and the host marked.

## World and server settings

Open the Escape menu and choose **Game settings** in local play or **Server settings** in multiplayer. Change the world name, Survival/Creative mode, difficulty, time of day, and the supported game rules: keep inventory on death, allow editing signs, and mob griefing. The host can also change the player limit (1–16); lowering it does not disconnect existing players. Guests can view settings but only the host can change them. Settings are saved with the world and shared with connected players.

## Dedicated server

Run from the project directory:

```sh
godot --headless --path . -- --server --port=24570 --seed=8675309
```

Use `--world=<world-id>` instead of `--seed` to load an existing saved world, and add `--creative` for creative mode. The server prints both its listening address and a local join address when the world is ready. Stop it normally to save the world.

## Customize your character

Choose **Character** from the title or pause screen. Change your display name, skin tone, hair, shirt, trousers, boots, hat, and body build, with a live 3D preview. **Save character** stores your appearance locally and updates it for connected players. Your first-person hand also uses your chosen skin and shirt colors.

## Verification

`./tests/run_tests.sh` runs gameplay regressions, including the steam machinery tests. `./tests/run_network_tests.sh` launches separate host and guest processes to verify binding, joining, shared blocks and chests, avatar appearance, copyable local addresses, and reconnecting. `tests/character_tour.gd` and `tests/steam_tour.gd` provide windowed visual checks.
