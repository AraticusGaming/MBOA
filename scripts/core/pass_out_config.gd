class_name PassOutConfig
extends Resource
## Pass-out penalty (GDD "Core loop and daily time"): passing out at 2:00 AM
## costs a percentage of the money the player is carrying, plus a fixed drop
## in bonding for the monsters they have with them. The player wakes in bed.
##
## docs/DECISIONS.md (2026-11-01): the player loses 10% of what they carry
## (money only, not items - confirmed). No cap. The bonding drop is still
## undecided: it stays 0 and inactive until monsters exist.

## Fraction (0..1) of carried Coins lost when passing out (ruling: 0.1).
@export_range(0.0, 1.0, 0.01) var gold_penalty_fraction: float = 0.1
## Fixed Bond drop, in Bond percentage points (Bond bar is 0-100%), applied to
## every monster in the player's party when passing out. PLACEHOLDER 0 (open).
## Inactive until monsters exist (Milestone 2+).
@export_range(0.0, 100.0, 0.5) var party_bond_drop: float = 0.0
## DECISIONS.md: passing out also costs about 1-3% reputation. Fraction (0..1)
## of reputation lost. PLACEHOLDER 0.02, INACTIVE until reputation exists
## (a later milestone); apply_sleep() does not read it yet.
@export_range(0.0, 1.0, 0.005) var reputation_penalty: float = 0.02
