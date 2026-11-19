# Dark Souls Demake

A turn-based Dark Souls demake built with [LÖVE2D](https://love2d.org/). Explore a small open
world, then fight through a reaction-based combat system where every enemy attack is a
telegraphed check: read the color, read the direction, react in time — or eat the hit.

## Running

```bash
love .
```

Requires LÖVE2D 11+.

## Controls

| Context | Input | Action |
|---|---|---|
| Menu | Click / SPACE | Start |
| Menu | Click / ESC | Quit |
| World | W / A / S / D | Move |
| World | R | Restart (back to main menu) |
| Combat | Click / 1 / 2 / 3 | Light / Heavy / Special attack (stamina cost 1 / 2 / 3) |
| Combat | Click Yield / SPACE | Cede the initiative (remaining stamina becomes your defense) |
| Combat | W / A / S / D | Evade in the indicated direction |
| Combat | P | Parry (yellow attacks only) |
| Combat | R | Restart (after death) |

## Combat mechanics

Combat runs on **stamina tempo**. Both sides have their own stamina pool, and whoever
has more stamina remaining holds the initiative. After every action the pools are
compared: if the enemy has at least as much stamina left as you, it cuts in with a
telegraphed strike; otherwise you keep acting. An exchange ends when a side can no
longer afford its cheapest action, and both pools refill. The enemy visibly winds up and
lunges before the hit lands — watch the color and direction and react in time.

- **Action points** — each attack costs stamina (1/2/3). A faster (higher-stamina) enemy
  interrupts sooner; an exhausted enemy yields the tempo back to you.
- **Defense pool** — when the enemy seizes the initiative, your remaining stamina becomes
  a **defense pool** that pays for evades and parries. Attacking less (or Yielding)
  leaves more stamina to defend with.
- **Yield** — cede the initiative on purpose to keep stamina banked for defense.
- **Telegraphs** — every enemy attack flashes during a warning window, then the enemy
  lunges while a short i-frame reaction window is open.
  - **RED attack** — cannot be parried. Evade in the direction shown.
  - **YELLOW attack** — can be parried with `P` (reflects enemy attack damage back) or
    evaded like a red one.
- **Directional evasion** — the attack tells you where it's coming from (top/left/right/
  bottom); press the matching direction. "Around" attacks accept any direction.

## Enemies

| Enemy | HP | ATK | Stamina | Atk cost | Telegraph | Behavior |
|---|---|---|---|---|---|---|
| Hollow | 60 | 12 | 4 | 2 | 1.20s | Low tempo, mostly yellow — parry practice |
| Knight | 80 | 15 | 5 | 2 | 1.00s | Balanced tempo and mix |
| Brute | 130 | 22 | 6 | 3 | 0.85s | High tempo, mostly red — dodge or die |
| **Ashen Lord** (boss) | 300 | 25 | **8** | 3 | **0.65s** | Very high tempo, everything, faster |

## Goal

Defeat all 5 roaming enemies to draw out the **Ashen Lord**, then slay it to win.

## Project structure

```
main.lua           Entry point: player/world init, world generation, game over / victory
state_manager.lua  Minimal finite state machine
menu_state.lua     Main menu, victory, and game over screens (clickable buttons)
world_state.lua    Exploration, item pickups, enemy/boss encounters
combat_state.lua   Turn-based reaction combat engine (Darkest Dungeon-style layout)
enemies.lua        Enemy archetypes and boss definition
sprites.lua        Sprite sheets and transform-based animation fx
ui.lua             Shared clickable button helpers
```
