# Changelog

## 1.2.0
- **Shopping:** buys from the shop and the skill tree by itself, picking whatever pays for itself fastest based on what each tool earns this run. It saves up when something better is less than 30 s away, and favours finishing a set of three for void tools. Off by default.
- **Skip fox pals for now:** no fox pals or fox upgrades while Full bag or Legendary bag is still missing (on by default). **Buy hats** is optional and waits until the last hat has found a pal.
- **Prestige upgrades:** spends worms on the advisor's BEST pick whenever you can afford it. **Prestige by itself** (off by default) prestiges once new upgrades are affordable and the run slows down. The prestige tree then waits for you, unless **Start the next run by itself** is on: then it presses Play in the world you pick (by default the latest unlocked one before the Void).
- **Autopilot tab:** next to Session stats in the game's tab column (or **A**): a big AUTO-BUY switch, the next purchase with a countdown and payback time, the queue after it and prestige status, with the shop options, the next buys and what was just bought in one card, then the other settings grouped into four foldable cards of two-column switches (hotkeys, achievements and reset stay in Options).
- **Fast buying:** it buys in bursts (dozens per tick when the dirt is there), so it keeps up early in a run after a big prestige. Repeat buys show as one line ("Spoon x12").
- **Next relic and next chest:** two bars right under the dirt and sand counters: how close the next relic is, and the next chest with its icon (hidden once every chest has been opened in earlier runs). Details on hover.
- **Settings moved to the Autopilot tab:** every switch now lives there, each card with a switch for all of it. **Options → Dirt Autopilot** keeps Enable all / Disable all, the achievements checklist, hotkeys and reset.
- **Sweep guides removed** (and their F6 hotkey): the dots and ring over the field were only for watching the sweeper.
- **Session stats per save slot:** each save keeps its own run and all-time stats; loading another slot switches over.
- The mod's tabs have gold icons, so they stand out from the game's own, with Autopilot first. The tab shows when the shop is sold out and the skill tree fully upgraded.

## 1.1.9
- **Session stats per run:** the tab now has **Run** (since your last prestige, the default) and **All time** views. All-time totals are kept between game launches (`DirtAutopilot/stats.json`). The reset button is gone.
- **Tools this run:** the Run view ranks your tools by the dirt they earned, with name, icon, share in % and a bar, dirt earned and dirt/s over the last minute, so you can tell them apart without the game graph's colours.
- **Read from your save:** Minigames done, Chests opened and Sand Mines upgrades maxed show your save's progress (e.g. "5 / 8"), Hats worn counts the pals wearing a hat, and All time shows the achievements you own out of all of them. Since game 1.3 minigames and chests are done once per save, so a new run used to show "0 / 0".
- Prestiges only show in All time.
- Clearer icons: the items icon was cut off, and small icons now fill their space; Void tools fused has the void icon.

## 1.1.8
- **New 1.3 achievements in the list:** "Create 10 void …" for every tool that can fuse (with "n / 10" progress) and the Sandy ones for every Sand Mines upgrade (earned by "Spend sand on upgrades").
- **Prestige advisor knows Void tools:** void unlocks and void dirt upgrades now rank near the top.
- **Faster relic opening:** relics you've found before open in 0.25 s, like in the game.
- **Session stats:** new "Void tools fused" and "Sand dug" rows.

## 1.1.7
- **Updated for Dirt Clicker 1.3.1.**
- **Skip flying dirt and worms removed:** the game's own **Particles** option (Options > Video) does the same job faster. If you had the mod's option on, the game's one is switched off for you once.
- Fixed the milestone bar breaking on 1.3 (chests now open once for good, and the bar skips them like the game does).
- Hats on pals works with the game's new "name pals" option off (no names are given then).
- Achievements: **Legendary bag** progress shows the game's real goal (64) instead of the new max stack size, and **Full bag** and **Legendary hourglass** were added to the list.

## 1.1.6
- **Relic and achievement popups are skipped without a flash:** with "Skip relic popups" or "Skip achievement popups" on, the popup is closed before it's ever drawn, instead of showing for a split second.
- Fixed an error in the log when the last item of a stack was sold by holding it, sold by a fox pal or opened as a relic (a game bug the mod now works around for every item, not only relics).

## 1.1.5
- **Settings reorganised** into **Automations**, **Quality of life** and **Setup**. Performance sits right at the top. "Protect legendary items" and the popup skips moved to Quality of life, and coffee and chests are now under **Pickups**.
- **Collapsible cards:** Performance, Hats on pals and Achievements open and close with a click, and their main switch and status ("3/7 on", "On", "12/40 unlocked") stay visible while closed. Performance has one switch for all of its options.

## 1.1.4
- **Session stats tab:** session stats moved out of the settings into their own tab, after Badges in the game's tab column, laid out to fit the side panel. Open or close it with **C** (hover the tab to see the key).
- Removed the Insert status message and the "Show hotkey messages" setting. Hotkey messages always show.

## 1.1.3
- **More Performance options**, all off by default: hide buff icons on tools and pals, stomp circles, pal names, sell amounts in the inventory and the "+N" on new items. Hidden buff icons also stop updating, which saves the most.
- **Next-milestone bar** moved to the top-left, right under your dirt per second.

## 1.1.2
- **Performance** section, both off by default:
  - **Skip flying dirt and worms:** dirt and worms land on your counter at once instead of flying there. The biggest FPS saver late in the game.
  - **Hide dig effects:** no dust puffs, zap lines or item pops when tools trigger.
- The mod itself does less work per frame: automations that don't need frame timing run 10 times a second, the milestone bar looks up the timeline 10 times a second, and the sweep guides reuse the auto-sweeper's scan.
- The prestige advisor is always on; its setting is gone.

## 1.1.1
- **Prestige advisor:** marks the best upgrade to buy in the prestige tree with **BEST**, and the prestige alert names it. Its picks favour what the mod's automations make the most of: new worlds and dirt boosts first, cursor radius while auto-sweep is on, sand upgrades, and never minigame auto-solve while the mod solves them.

## 1.1.0
- **Session stats** are now tiles with the game's icons: three headline numbers (play time, dirt earned, dirt per hour) and a grid that fits the window. New: worms earned, items per hour, sand upgrades, hats placed, prestiges and achievements.

## 1.0.9
- **Achievements:** a checklist of the game's achievements in the settings, with progress for the counted ones and which feature earns each. **Do it** handles two chores: clicking the cookie relic 999 times (Dragoon) and the volume one (Connor LP; your volumes aren't changed).

## 1.0.8
- **Prestige alert** shows the icon of the first upgrade prestiging unlocks, instead of always the worm. Fixed its text being squeezed into a narrow column.
- **Simpler settings:** removed **Extra wait per spot**, **Answer after**, **Start it when it's ready** (the timer game now always starts itself), the sand **Order** (sand always fills every upgrade) and **Alert at** (the prestige alert fires from the first new upgrade).
- On by default: **Show sweep guides** and **Spend sand on upgrades**.

## 1.0.7
- **Pal names:** pals that get a hat are named after people from the game's credits, and no two pals share a name. The first one is always **Todd**, which unlocks the "name a pal Todd" achievement.

## 1.0.6
- **Spend sand on upgrades:** picks which Sand Mines upgrades to fill, so you don't have to click them. All upgrades fill at once.
- Settings: the Sand Mines timer and sand upgrades now share a **Sand Mines** section; the relic minigame solver moved to **Relics & items**.

## 1.0.5
- **Hat preferences:** each hat goes on a pal it actually helps. For example, hard hats skip pals that don't dig, such as the Druid and the Dirt golem, and antenna hats go to stomping pals like the Frog. Every hat has a dropdown to pick which pal gets it first, or leave it on **Best fit**. If no suitable pal is free, the hat waits for you.

## 1.0.4
- **Next milestone:** a bar in the bottom-left of the play field shows the next chest or relic and how close you are. Known milestones show their icon, random relics show a **?**. Hover for the name and exact numbers.
- On by default: legendary protection, putting hats on pals, the milestone bar and the prestige alert. Settings you already saved are kept.

## 1.0.3
- **Prestige alert:** lets you know when prestiging would give enough worms for more prestige upgrades. Click it to view the prestige tree. Choose how many new upgrades it takes before you're alerted.

## 1.0.2
- **Put hats on pals:** each new hat goes on a pal that doesn't have one yet.

## 1.0.1
- **Update check:** when the game starts, the mod looks for a newer release on GitHub. If there is one, an alert and an **Update** button in the settings link to the download page.

## 1.0.0
- First release.
