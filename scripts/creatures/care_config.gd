class_name CareConfig
extends Resource
## Monster care and bonding numbers (resources/monsters/care_config.tres).
## GDD gives the rules (feeding the favorite food raises bonding more, barn
## monsters need food and water every day, party monsters gain passive
## bonding) but no numbers: every number here is NOT GDD, PLACEHOLDER
## (docs/PLACEHOLDERS.md "Slice 3").

const PASTURE_PATH := "res://resources/buildings/pasture.tres"
const BARN_PATH := "res://resources/buildings/barn.tres"

## Bond points (0-100 bar) for feeding the monster's favorite food.
@export var feed_bond_favorite: float = 6.0
## ...food of its preferred food type (SpeciesData.preferred_food_type).
@export var feed_bond_preferred: float = 3.0
## ...any other feedable food.
@export var feed_bond_other: float = 1.0
## GDD: "continuously feeding a monster its favorite food raises bonding".
## Extra points per consecutive day it got its favorite, up to the cap.
@export var favorite_streak_bonus: float = 1.0
@export_range(0, 30) var favorite_streak_cap: int = 5
## Feeds per monster per day that give bond; later feeds still count as fed.
@export_range(1, 20) var bond_feeds_per_day: int = 2
## GDD: party monsters gain passive bonding. Points per day in the party.
@export var party_bond_per_day: float = 2.0
## GDD: barn monsters need food and water every day. Bond lost at day end by
## a barn monster (not out with the party) missing either.
@export var barn_neglect_bond_drop: float = 3.0
## Party members are with the player, so they skip the barn's food/water check.
@export var party_skips_barn_care: bool = true
## GDD opening (Angie's walkthrough, skipped): 20 special foods that always
## count as a favorite and 45 seeds of the monster's favorite crop. Given
## with the first monster while the opening is skipped.
@export var angie_gift_enabled: bool = true
@export var angie_treat_id: StringName = &"angie_treat"
@export_range(0, 999) var angie_treat_count: int = 20
@export_range(0, 999) var angie_seed_count: int = 45
