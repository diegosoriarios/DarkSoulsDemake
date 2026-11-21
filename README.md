# Lanternfall

A turn-based action-RPG demake built with [LÖVE2D](https://love2d.org/). Traverse the
Guttering Reach, fell its Wardens for their Embers, spend Lumen at the Vigil, and part
the Northlight fog to face the Guttering King.

## Running

```bash
love .
```

Requires LÖVE2D 11+.

## Game loop

1. Rest at the **Vigil** in Wayfarer's Rest (heal, respawn regular foes).
2. Explore the ring-and-spokes Reach: **The Salt Flats**, **The Drowned Archive**, and
   **The Fungal Terrace**, linked by **The Broken Aqueduct**.
3. Fell the three Wardens (**Brine Warden**, **Tidewarden**, **Sporecaller**) to claim
   their **Embers**; collect **Lumen** from every foe.
4. Spend Lumen at the Vigil on upgrades, and take the optional **Sunken Cistern** detour.
5. With three Embers the **Northlight fog** parts and the **Guttering King** rises.
6. Defeat the King to win. **Death scatters your Lumen as a Lost Lantern**; you wake at
   the last Vigil you rested at, and the Lantern waits where you fell.

## Controls

| Context | Input | Action |
|---|---|---|
| Menu | Click / SPACE | Continue (if a save exists) or start |
| Menu | Click / ESC | Quit |
| World | W / A / S / D | Move |
| World | E | Rest or travel at a Vigil / open caches / use passages |
| World | H | Drink a Lantern Draught (+40 HP) |
| World | F | Invoke a Beacon Sigil to summon the Lantern-Bearer |
| World | TAB | Open/close the map and journal |
| World | R | Restart the run (erases autosave) |
| Combat | Click / 1 / 2 / 3 | Light / Heavy / Special attack (stamina cost 1 / 2 / 3) |
| Combat | Click an enemy / TAB | Switch target (up to three foes) |
| Combat | Shift button / 4 | Swap front/back rows with your ally (costs 1 stamina) |
| Combat | Click Yield / SPACE | Cede the initiative (remaining stamina becomes defense) |
| Combat | W / A / S / D | Evade in the indicated direction |
| Combat | P | Parry (yellow attacks only) |
| Combat | R | Restart the run (during the death animation) |

## Areas

The map is a compact ring-and-spokes with tile collision, doors and fog gates:

- **Wayfarer's Rest** (hub) — the Vigil.
- **The Salt Flats** (west) — Brine Warden.
- **The Drowned Archive** (east) — Tidewarden.
- **The Fungal Terrace** (south) — Sporecaller.
- **The Broken Aqueduct** — shortcut loops opened by the Wardens' Embers.
- **The Northlight Gate** (north) — fog sealed until three Embers are claimed.
- **Side dungeons** — **The Sunken Cistern**, **The Drowned Vault**, and **The Spore
  Hollow**, each with a mini-boss, a sealed cache, and a Vigil (Cistern).

Vigils are checkpoints: resting heals, respawns regular enemies, **light the Vigil**
and set your respawn point. Lit Vigils appear as travel destinations when you rest at
any other Vigil.

Map and journal (TAB) show the current area's rooms, doors, gates, Vigil, living
guardians, the player, objectives, Lumen, Embers, and discovered areas.

## Combat mechanics

Encounters can hold **up to three enemies** at once. Click a foe or press TAB to pick
your target; each enemy tracks its own HP and stamina, and downed foes stay down (their
collapse plays while the fight continues). The enemy side acts with its freshest living
member, so a group can trade initiative back and forth as their stamina drains.

Combat runs on **stamina tempo**. Both sides have their own stamina pool, and whoever
has more stamina remaining holds the initiative. After every action the pools are
compared: if the enemy has at least as much stamina left as you, it cuts in with a
telegraphed strike; otherwise you keep acting. An exchange ends when a side can no
longer afford its cheapest action, and both pools refill.

- **Action points** — each attack costs stamina (1/2/3).
- **Defense pool** — when the enemy seizes the initiative your remaining stamina becomes
  a defense pool for evades and parries.
- **Telegraphs** — RED attacks must be evaded in the shown direction; YELLOW attacks can
  be parried with `P` or evaded.
- **Momentum** — the knight animates idle/run, attack, hurt, block and death; hits flash,
  recoil and shake the screen.
- **Death** — when you fall, your Lumen drops at that spot as a **Lost Lantern**. You
  respawn at your last rested Vigil with full HP; touch the Lantern to reclaim the Lumen.
  Dying again with Lumen replaces the old Lantern.

## Dungeons, caches and farming

Each side dungeon has 2–4 rooms of regular foes (they respawn when you rest), a
**mini-boss** that guards a **sealed cache**, and a way back to its parent area. Touching
the mini-boss starts a solo fight; falling to it costs no Embers, but the cache stays
sealed until it dies.

Caches contain **permanent trinkets**, Lumen, and consumables:

| Trinket | Effect | Found in |
|---|---|---|
| Ember Shard | +1 Max Stamina | Sunken Cistern |
| Hone Shard | +3 Attack | Drowned Vault |
| Vessel | +20 Max HP | Spore Hollow |

Caches also drop **Lantern Draughts** (press `H` to drink one for +40 HP) and **Beacon
Sigils** (press `F` to summon the Lantern-Bearer). Regular dungeon foes are worth more
than road encounters, and resting at any Vigil respawns them for farming — mini-bosses
stay dead once felled.

## Summons and rows

**Beacon Sigils** (found in dungeon caches) summon the **Lantern-Bearer**, a spectral
knight who fights beside you for up to **three encounters** or until they fall. While
summoned, the party uses **front/back rows**: the ally joins the front (you start in the
back), and melee enemies strike the front first. Swap rows with the **Shift** action
(costs 1 stamina) to tank or to send the ally forward.

- The Lantern-Bearer fights on its own stamina with the same tempo rules (the freshest
  combatant acts; ties favour you, then the ally, then enemies).
- Enemies aim at the front row; the ally has no dodge window, but its defense reduces
  damage. If it falls, you step to the front.
- Resting at a Vigil heals the ally; each finished encounter uses one of its three
  battles. Your ally is lost if you die, and the summon persists in the save.
- HUD shows the ally's remaining battles; `F` in the world summons (needs a Sigil).

## Vigil upgrades

| Upgrade | Effect | Ranks | Base cost |
|---|---|---|---|
| Vitality | +20 Max HP | 3 | 40 lumen |
| Might | +3 Attack | 3 | 50 lumen |
| Breath | +1 Max Stamina | 2 | 60 lumen |
| Ward | +2 Defense | 2 | 40 lumen |

Costs rise with each rank.

## Enemies

| Enemy | HP | ATK | Stamina | Atk cost | Telegraph | Lumen |
|---|---|---|---|---|---|---|
| Thrall | 60 | 12 | 4 | 2 | 1.20s | 12 |
| Shard Acolyte | 80 | 15 | 5 | 2 | 1.00s | 18 |
| Bloater | 130 | 22 | 6 | 3 | 0.85s | 25 |
| Brine Warden (guardian) | 90 | 14 | 4 | 2 | 1.05s | 100 + Ember |
| Tidewarden (guardian) | 120 | 18 | 5 | 2 | 0.95s | 100 + Ember |
| Sporecaller (guardian) | 170 | 24 | 6 | 3 | 0.80s | 100 + Ember |
| **The Guttering King** (boss) | 300 | 25 | 8 | 3 | **0.65s** | — |

## Saving

A single autosave slot (version 5) stores player stats, position and current area,
Lumen, Embers, upgrades, trinkets and consumables, opened caches, opened doors,
discovered areas, defeated enemies, lit Vigils, the last rested Vigil, the Lost Lantern,
and any active ally. It is written on enemy defeats, deaths,
rests, upgrades, travel and victory.

## Roadmap

Phase 1: areas, collision, doors/fog gates, the Sunken Cistern stub, the map/journal,
and the Lanternfall reskin. Phase 2: Lost Lantern death retrieval and Vigil fast travel.
Phase 3: multi-enemy encounters with target switching. Phase 4: side dungeons,
mini-bosses, caches, trinkets, draughts and farming. Phase 5 (current): the Lantern-Bearer
summon ally with front/back row combat. Next: balance, polish, and a full text/UI pass.

## Project structure

```
main.lua           Entry point: world build, area travel, save/load, victory/death
state_manager.lua  Minimal finite state machine
menu_state.lua     Main menu, victory, and game over screens
world_state.lua    Area exploration, collision, doors, HUD, map/journal
combat_state.lua   Turn-based stamina-tempo combat
bonfire_state.lua  The Vigil: rest and upgrades
enemies.lua        Archetypes, guardians, boss, Lumen rewards
areas.lua          Rooms, floors, doors, transitions, spawns and items
collision.lua      Tile-based AABB movement with sliding
progress.lua       Objectives, Lumen, Embers, doors, discoveries, upgrades
save.lua           Single-slot sandboxed autosave (v5)
sprites.lua        Knight animation sheets and enemy fx
ui.lua             Shared clickable button helpers
```
