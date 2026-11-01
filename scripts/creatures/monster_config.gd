class_name MonsterConfig
extends Resource
## Monster rules (resources/monsters/monster_config.tres). GDD values are
## marked GDD; the rest are placeholders (docs/PLACEHOLDERS.md).

## GDD: Bond bar 0-100%.
@export var bond_max: float = 100.0
## GDD: at 25% a monster can be sent to the barn.
@export var barn_bond: float = 25.0
## GDD: at 100% it gains the breeding star.
@export var star_bond: float = 100.0
## GDD: up to two monsters with the player.
@export_range(1, 6) var party_max: int = 2
## PLACEHOLDER: how far (in letters) a rolled stat may be from the target
## overall rank before the overall-rank check (see MonsterFactory).
@export_range(0, 4) var letter_spread: int = 1
## PLACEHOLDER: chance (0..1) a new monster is female (GDD: gender random).
@export_range(0.0, 1.0, 0.01) var female_chance: float = 0.5
