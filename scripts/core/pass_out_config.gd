class_name PassOutConfig
extends Resource
## Pass-out penalty (GDD "Core loop and daily time"): passing out at 2:00 AM
## costs a percentage of the money the player is carrying, plus a fixed drop
## in bonding for the monsters they have with them. The player wakes in bed.
##
## OPEN QUESTION (GDD): the percentage and the size of the bonding drop are not
## decided. Both default to 0 (no penalty) until the design owner sets them in
## res://resources/pass_out_config.tres.

## Fraction (0..1) of carried Coins lost when passing out. PLACEHOLDER 0.
@export_range(0.0, 1.0, 0.01) var gold_penalty_fraction: float = 0.0
## Fixed Bond drop, in Bond percentage points (Bond bar is 0-100%), applied to
## every monster in the player's party when passing out. PLACEHOLDER 0.
## Inactive until monsters exist (Milestone 2+).
@export_range(0.0, 100.0, 0.5) var party_bond_drop: float = 0.0
