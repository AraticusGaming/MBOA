class_name AssessmentConfig
extends Resource
## The Assessment (GDD "Opening", step 3): the player picks a Biome room, Angie
## gives 5 traps, creatures move at random, the player places a trap near a
## monster and sees whether it takes the bait; each monster's rank is shown;
## ranks are D 79% / C 20% / B 1%; after one capture the player can end and
## keep it, or use all 5 traps and choose one. Slice 2 builds one room
## (Woodland, roadmap). Values not in the GDD are PLACEHOLDERS
## (docs/PLACEHOLDERS.md).

## Room biome (SpeciesData.Biome). Slice 2: Woodland only.
@export var biome: SpeciesData.Biome = SpeciesData.Biome.WOODLAND
## GDD: Angie gives 5 traps.
@export_range(1, 20) var trap_count: int = 5
## GDD: rank odds in the Biome rooms (weights, need not sum to 100).
@export var rank_weights: Dictionary = {"D": 79.0, "C": 20.0, "B": 1.0}
## Species weights by id (empty = every wild species of the biome equally).
## PLACEHOLDER.
@export var species_weights: Dictionary = {}

@export_group("Placeholders")
## Creatures in the room at the start. PLACEHOLDER.
@export_range(1, 20) var creature_count: int = 6
## Room area creatures and traps use (room-local pixels, 640x360 screen).
@export var room_rect: Rect2 = Rect2(24, 56, 592, 280)
## Wandering speed (px/s) and how often a creature picks a new direction.
@export var creature_speed: float = 24.0
@export var wander_change_seconds: float = 1.6
## Chance (0..1) per wander change that a creature stands still instead.
@export_range(0.0, 1.0, 0.05) var idle_chance: float = 0.3
## A creature within this distance (px) of a set trap goes for the bait.
@export var lure_radius: float = 44.0
## Speed (px/s) of a creature walking to a trap.
@export var lure_speed: float = 30.0
## Chance (0..1) the trap holds once the creature takes the bait (else it is
## knocked over and the bait is gone - GDD trapping rule).
@export_range(0.0, 1.0, 0.05) var catch_chance: float = 0.65
## Seconds the closed trap shakes before the catch is confirmed (GDD: the trap
## closes and starts to shake).
@export var shake_seconds: float = 1.2
## Seconds a creature that knocked a trap over ignores other traps.
@export var spooked_seconds: float = 4.0
## Minimum distance between traps (px).
@export var min_trap_spacing: float = 14.0
## How far from the player (px) a trap can be placed by click/tap.
@export var place_reach: float = 40.0
## Failed traps are spent (the GDD says the bait is gone; whether the trap
## can be re-baited is not stated). If every trap is spent with nothing
## caught, Angie hands out a fresh set. PLACEHOLDER.
@export var refill_when_empty: bool = true
## The chosen monster joins the party instead of living in its habitat.
## GDD: wild-caught monsters live in their biome's habitat until bonded and
## the party is taken from the barn, so this is off. PLACEHOLDER toggle.
@export var first_monster_joins_party: bool = false
## Clock is paused inside the Assessment room. PLACEHOLDER.
@export var pause_clock: bool = true
