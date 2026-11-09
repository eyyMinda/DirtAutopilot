# Dirt Autopilot

An in-game automation helper for **Dirt Clicker**. It's the in-game successor to the [Dirt Sweeper](https://github.com/eyyMinda/Dirt-Sweeper) overlay. Unofficial and fan-made; not affiliated with the developers of Dirt Clicker.

Everything is **off until you switch it on**, in **Options → Dirt Autopilot**.

## What it can do

| Section | Feature |
| --- | --- |
| Auto-sweeper | Moves the hover circle onto tools that are ready, as many per stop as possible. Your real mouse is never moved, and when nothing is ready the circle follows your mouse as usual. |
| Minigames | Plays the Sand Mines timer for a PERFECT every round (and can start it when it's ready). Solves the relic minigames: words, math cards, dice and the rest. |
| Relics & items | Opens your relics one at a time. Protects legendary items from fox pals and Sell All. |
| Extras | Grabs the coffee bean, opens chests you have the key for, and skips relic and/or achievement popups. |
| Session stats | Play time, dirt per hour, items, relics, minigames, coffee beans and chests since you started the game. |

## Install

Dirt Autopilot needs a mod loader. It works with both the Godot Mod Loader and DirtLoader from Nexus Mods.

1. Install your mod loader by following its own instructions.
2. Download `eyyMinda-DirtAutopilot-<version>.zip` from the [latest release](https://github.com/eyyMinda/DirtAutopilot/releases/latest).
3. Put the mod where your loader looks for mods:
   - **Godot Mod Loader:** put the `.zip` as-is in `<game folder>\mods\`.
   - **DirtLoader:** extract the zip into `<game folder>\mods\`, so you get `<game folder>\mods\eyyMinda-DirtAutopilot\`.
4. Start the game and open **Options → Dirt Autopilot**. With DirtLoader, **Options → Mods → Settings** opens the same page.

## Hotkeys

| Key | Action |
| --- | --- |
| F5 | Auto-sweep on/off |
| F6 | Sweep guides on/off: a dot on each ready tool, a ring where the sweeper is |
| F7 | Sand Mines timer on/off |
| Insert | Show what's switched on, plus play time and dirt for this session |
| F9 | Open or close the Dirt Autopilot settings |

To change a key, click it in the **Hotkeys** section, then press the new one. Esc cancels and Backspace removes it.

## Good to know

- **Protect legendary items** locks them, so you can't sell them by hand either while it's on. Switch it off to sell them.
- **Open relics** only opens relics that start a minigame while **Solve relic minigames** is on, so a minigame never pops up by surprise.
- While auto-sweep holds the circle on some tools, clicking a chest or other clickable thing in the field uses the circle's position, not your mouse. Press F5 to pause it.
- DirtLoader turns Steam achievements off while mods are loaded, unless you enable them in **Options → Mods**. That's DirtLoader's setting, not this mod's.

Settings are saved to `%APPDATA%\Godot\app_userdata\Dirt Clicker\DirtAutopilot\settings.json`. **Reset all settings** at the bottom of the page restores the defaults.

## Uninstall

Delete the mod's folder or zip from `<game folder>\mods\`. To remove its settings too, delete `%APPDATA%\Godot\app_userdata\Dirt Clicker\DirtAutopilot\`.

## Releasing (maintainers)

Releases are built by GitHub Actions ([.github/workflows/release.yml](.github/workflows/release.yml)) and attached as `eyyMinda-DirtAutopilot-<version>.zip`, containing the `eyyMinda-DirtAutopilot/` folder (the scripts, `manifest.json`, `README.md` and `LICENSE`).

- **From GitHub:** Actions → Release → Run workflow, enter the new version (e.g. `1.0.1`). It updates `version_number` in `manifest.json`, commits, tags `v1.0.1` and publishes the release.
- **From git:** set `version_number` in `manifest.json`, commit, then `git tag v1.0.1 && git push origin v1.0.1`. The workflow fails if the tag and manifest version differ.

## License

Dirt Autopilot is licensed under the [GNU General Public License v3.0](LICENSE).
