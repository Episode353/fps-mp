extends Resource

class_name Weapon_Resource

@export var weapon_name: String

# Animations
@export var activate_anim: String
@export var shoot_anim: String
@export var reload_anim:String
@export var deactivate_anim: String
@export var out_of_ammo_anim: String
@export var wall_raise_anim: String
@export var wall_lower_anim: String

# Ammo Controls
@export var current_ammo: int
@export var reserve_ammo: int
@export var mag_ammo: int
@export var max_ammo: int
@export var damage: int
@export var weapon_range: int # Only for Hitscan Weapons


# Weapon type 
@export var auto_fire: bool
@export var disable_wall_prox: bool
@export var disable_ammo: bool

# Area Damage (flamethrower)
@export var use_area_damage_collision: bool # This can be used for flamethrowers, or distance based spells
@export var area_damage_radius: int # Controls Damage Radius of area damage collision weapons 

