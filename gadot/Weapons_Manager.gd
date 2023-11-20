extends Node3D

signal weapon_changed
signal update_ammo
signal update_weapon_stack

@onready var animation_player = $FPS_RIG/AnimationPlayer

var current_weapon = null
var weapon_raise = false
var weapon_stack = [] # An array of all weapons the player has
@onready var raycast_shoot = $"../raycast_shoot"
var weapon_indicator = 0
var next_weapon: String
@onready var ac_timer = $"../area_collision/Timer"

@onready var bullet_decal = preload("res://tscn/bullet_decal.tscn")

var weapon_list = {}
@export var _weapon_resources: Array[Weapon_Resource]
@onready var raycast_wall = $"../../../../raycast_wall"
@onready var area_collision = $"../area_collision"

@export var start_weapons: Array[String]

func _ready():
	Initalize(start_weapons) # Enter the state machine
	
func _input(event):
	if not is_multiplayer_authority(): return
	if event.is_action_pressed("weapon_up"):
		weapon_indicator = (weapon_indicator + 1) % weapon_stack.size()
		exit(weapon_stack[weapon_indicator])

	if event.is_action_pressed("weapon_down"):
		weapon_indicator = (weapon_indicator - 1 + weapon_stack.size()) % weapon_stack.size()
		exit(weapon_stack[weapon_indicator])

	if event.is_action_pressed("shoot") && weapon_raise == false:
		shoot()
	
	if event.is_action_pressed("reload"):
		reload()
	



func Initalize(_start_weapons: Array):
	if not is_multiplayer_authority(): return
	# Create a Dictionary to refer to our weapons
	for weapon in _weapon_resources:
		weapon_list[weapon.weapon_name] = weapon

	for i in _start_weapons:
		weapon_stack.push_back(i) # Add our start weapons

	current_weapon = weapon_list[weapon_stack[0]]
	emit_signal("update_weapon_stack", weapon_stack)
	enter()

func enter():
	animation_player.queue(current_weapon.activate_anim)
	emit_signal("weapon_changed", current_weapon.weapon_name)
	emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])

	
func exit(_next_weapon: String):
	#In order to change weapons first call exit
	if next_weapon != current_weapon.weapon_name:
		if animation_player.get_current_animation() != current_weapon.deactivate_anim:
			animation_player.play(current_weapon.deactivate_anim)
			next_weapon = _next_weapon
	
func change_weapon(weapon_name: String):
	current_weapon = weapon_list[weapon_name]
	var weapon_range = current_weapon.weapon_range
	raycast_shoot.target_position.z = weapon_range
	print("Switched to Weapon: ", current_weapon.weapon_name)
	ac_timer.wait_time = current_weapon.fire_rate
	next_weapon = ""
	enter()



func _on_animation_player_animation_finished(anim_name):
	if anim_name == current_weapon.deactivate_anim:
		change_weapon(next_weapon)
		animation_player.play(current_weapon.activate_anim)
		
	if anim_name == current_weapon.shoot_anim && current_weapon.auto_fire == true && current_weapon.skip_animation_on_fire == false:
		if Input.is_action_pressed("shoot"):
			shoot()
			
		
		
func raycast_shoot_procc():
	
	var hit_position = raycast_shoot.get_collision_point()
	
	var hit_object = raycast_shoot.get_collider()

	# Place the Bullet Decal
	var col_nor = raycast_shoot.get_collision_normal()
	var col_point = raycast_shoot.get_collision_point()
	var b = bullet_decal.instantiate()
	raycast_shoot.get_collider().add_child(b)
	b.global_transform.origin = col_point

	if col_nor == Vector3.DOWN or col_nor == Vector3.UP:
		# For floors and ceilings, set rotation to face upwards
		b.rotation_degrees.x = 90
	else:
		# For walls, use look_at to orient the decal
		b.look_at(col_point - col_nor, Vector3(0, 1, 0))

	
	
	# Check if the hit object is a player
	if hit_object.is_in_group("players"):
		# Assuming the player has a "receive_damage" method marked as an RPC
		hit_object.rpc("receive_damage", current_weapon.damage)
		print(hit_object)
		print("Player Hit!")
	else:
		print("Hit object is not a player.")
	
	

	
func area_collision_procc():
	var ac_enim = area_collision.get_overlapping_bodies()
	for e in ac_enim:
		if e.is_in_group("players"):
			e.rpc("receive_damage", current_weapon.damage)
			
func shoot():
	if current_weapon.current_ammo != 0:
		# Wait for animation to finish before firing again
		# If Animation skip is on, skip
		if !animation_player.is_playing():
			animation_player.play(current_weapon.shoot_anim)
		if current_weapon.disable_ammo == false:
			current_weapon.current_ammo -= 1
			emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
		
		if raycast_shoot.is_colliding():
			raycast_shoot_procc()
			
		if current_weapon.use_area_damage_collision == true:
			area_collision_procc()
	else:
		reload()
	
func reload():
	if current_weapon.disable_ammo == false:
		if current_weapon.current_ammo == current_weapon.mag_ammo:
			return
		elif !animation_player.is_playing():
			if current_weapon.reserve_ammo != 0:
				animation_player.play(current_weapon.reload_anim)
				var reload_ammount = min(current_weapon.mag_ammo - current_weapon.current_ammo,current_weapon.mag_ammo,current_weapon.reserve_ammo)
				
				current_weapon.current_ammo = current_weapon.current_ammo + reload_ammount
				current_weapon.reserve_ammo = current_weapon.reserve_ammo - reload_ammount
				emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
				
				
			else:
				animation_player.play(current_weapon.out_of_ammo_anim)


func _physics_process(delta):
	if not is_multiplayer_authority(): return
	if current_weapon.disable_wall_prox == false:
		if raycast_wall.is_colliding() && !animation_player.current_animation == "current_weapon.wall_raise_anim" && weapon_raise == false:
			animation_player.queue(current_weapon.wall_raise_anim)
			weapon_raise = true
		elif !raycast_wall.is_colliding() && weapon_raise == true:
			animation_player.queue(current_weapon.wall_lower_anim)
			weapon_raise = false
			
	if current_weapon.use_area_damage_collision == true:
		if Input.is_action_just_pressed("shoot"):
			ac_timer.start()
		if Input.is_action_just_released("shoot"):
			ac_timer.stop()
			

func _on_timer_timeout():
	shoot()
