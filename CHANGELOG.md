# Changelog

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
