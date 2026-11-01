class_name PassOutConfig
extends Resource
## Penalties for passing out at pass_out_hour (2 AM) instead of going to bed.
##
## OPEN DESIGN QUESTION: the pass-out penalty is not decided yet. Every field
## defaults to 0 (= no penalty) so behavior is neutral until the design owner
## picks values in res://resources/pass_out_config.tres.

## Hours added to wake_hour the morning after passing out (applied by Clock).
@export_range(0.0, 12.0, 0.25) var wake_hour_delay: float = 0.0
## Fraction of max energy NOT restored after passing out (0..1, PlayerState).
## Energy itself is a placeholder until the energy system is designed.
@export_range(0.0, 1.0, 0.01) var energy_penalty_fraction: float = 0.0
## Fraction of current gold lost after passing out (0..1, PlayerState).
@export_range(0.0, 1.0, 0.01) var gold_penalty_fraction: float = 0.0
## Upper bound on gold lost (0 = no cap).
@export_range(0, 1000000) var gold_penalty_max: int = 0
