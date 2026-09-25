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

| Context | Key | Action |
|---|---|---|
| Menu | SPACE | Start |
| Menu | ESC | Quit |
| World | W / A / S / D | Move |
| World | R | Restart (back to main menu) |
| Combat | 1 / 2 / 3 | Light / Heavy / Special attack (stamina cost 1 / 2 / 3) |
| Combat | SPACE | Pass turn (banks remaining stamina as defense pool) |
| Combat | W / A / S / D | Evade in the indicated direction |
| Combat | P | Parry (yellow attacks only) |
| Combat | R | Restart (after death) |

## Combat mechanics

- **Stamina economy** — attacks cost stamina; you only take a turn from the enemy when
  you run out (or Pass). Unspent stamina is banked as a **defense pool**, which pays for
  evades and parries during the enemy's attack.
- **Telegraphs** — every enemy attack flashes during a warning window, then opens a short
  i-frame reaction window.
  - **RED attack** — cannot be parried. Evade in the direction shown.
  - **YELLOW attack** — can be parried with `P` (reflects enemy attack damage back) or
    evaded like a red one.
- **Directional evasion** — the attack tells you where it's coming from (top/left/right/
  bottom); press the matching direction. "Around" attacks accept any direction.

## Enemies

| Enemy | HP | ATK | Telegraph | Behavior |
|---|---|---|---|---|
| Hollow | 60 | 12 | 1.20s | Mostly yellow attacks — parry practice |
| Knight | 80 | 15 | 1.00s | Balanced mix |
| Brute | 130 | 22 | 0.85s | Mostly red — dodge or die |
| **Ashen Lord** (boss) | 300 | 25 | **0.65s** | Everything, faster. The real check |

## Goal

Defeat all 5 roaming enemies to draw out the **Ashen Lord**, then slay it to win.

## Project structure

```
main.lua           Entry point: player/world init, world generation, game over / victory
state_manager.lua  Minimal finite state machine
menu_state.lua     Main menu, victory, and game over screens
world_state.lua    Exploration, item pickups, enemy/boss encounters
combat_state.lua   Turn-based reaction combat engine
enemies.lua        Enemy archetypes and boss definition
```
