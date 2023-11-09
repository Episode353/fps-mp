extends CharacterBody3D

signal health_changed(health_value)

# Player Nodes

@onready var head = $neck/head
@onready var neck = $neck
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $neck/head/Camera3D/Pistol/MuzzleFlash
@onready var raycast_shoot = $neck/head/Camera3D/raycast_shoot
@onready var crouching_collision_shape = $crouching_collision_shape
@onready var standing_collision_shape = $standing_collision_shape
@onready var raycast_crouching = $raycast_crouching
@onready var camera_3d = $neck/head/Camera3D
@onready var raycast_wall = $raycast_wall

# Speed Variables

var health = 3

const walking_speed = 5.0
const sprinting_speed = 10.0
const crouching_speed = 3.0
var current_speed = 10.0
const JUMP_VELOCITY = 10.0
var lerp_speed = 20.0
var crouching_depth = -0.5
var standing_depth = 1.8
var free_look_tilt_ammount = 8

# States

var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

# Slide Vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 15.0


# Input Variables
const mouse_sens = 0.1
var direction = Vector3.ZERO


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_3d.current = true
func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120)) #How far left and right you can look like freelooking
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-98), deg_to_rad(89))

	
	if Input.is_action_just_pressed("shoot"):
		play_shoot_effects.rpc()
		if raycast_shoot.is_colliding():
			var hit_player = raycast_shoot.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Getting Movment Input
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	if Input.is_action_pressed("crouch") || sliding:
		
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y,crouching_depth, delta * lerp_speed)
		
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
		#Slide Begin Logic
		
		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			slide_vector = input_dir
			slide_timer = slide_timer_max
			free_looking = true
		
		walking = false
		sprinting = false
		crouching = true
		
	elif !raycast_crouching.is_colliding():
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		#Increase speed when sprint key is pressed
		if Input.is_action_pressed("sprint"):
			current_speed = sprinting_speed
			
			walking = false
			sprinting = true
			crouching = false
			
		else:
			current_speed = walking_speed
			
			walking = true
			sprinting = false
			crouching = false
	
	# Handle free looking
	if Input.is_action_pressed("free_look") || sliding:
		free_looking = true
		
		if sliding:
			camera_3d.rotation.z = lerp(camera_3d.rotation.z,-deg_to_rad(7.0),delta*lerp_speed)
		else:
			camera_3d.rotation.z = -deg_to_rad(neck.rotation.y*free_look_tilt_ammount)
	else:
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y,0.0,delta*lerp_speed)
		camera_3d.rotation.z = lerp(camera_3d.rotation.z,0.0,delta*lerp_speed)

	
	# Handle Sliding 
	
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	
	direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta*lerp_speed)
	
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x,0,slide_vector.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		if sliding:
			velocity.x = direction.x * (slide_timer + 0.5) * slide_speed
			velocity.z = direction.z * slide_timer * slide_speed
			
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)




	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	pass

@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = 3
		position = Vector3.ZERO
	health_changed.emit(health)

func _on_animation_player_animation_finished(anim_name):
	pass
