# Monster Breeders of Ahymn (MBOA)

A cozy 2D farming and creature-taming game for PC and mobile, built in Godot 4.
Stardew-style farming, clock, and seasons combined with Dragon Warrior Monsters-style
taming and breeding, plus optional tournaments.

## Pillars
1. Farming is integral.
2. Time is the resource.
3. Every creature is tamed in its own unique way.
4. Tournaments are optional.

## Art spec
16-bit pixel art, cozy Stardew-like style. 16x16 tiles, 16x32 characters, 64x64 portraits.

## Structure
- `scenes/`: Godot scenes (`world/`, `farm/`, `ui/`, `creatures/`)
- `scripts/`: GDScript (`core/`, `farm/`, `creatures/`, `ui/`)
- `assets/`: sprites, tilesets, portraits, audio, fonts
- `resources/`: custom `.tres` data (items, crops, creature definitions)
- `docs/`: roadmap and design notes. The GDD is the source of truth for design.

## Getting started
Open `project.godot` with Godot 4.3 or newer (developed on 4.x stable).
