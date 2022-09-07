extends KinematicBody

# Node References
onready var head = $Head
onready var camera = $Head/Camera
onready var raycast = $Head/Camera/RayCast
onready var block_outline = $BlockOutline

# Variables
var camera_x_rotation = 0
var velocity = Vector3()
var paused = false
onready var starting_pos = self.global_transform

# Constants
const mouse_sense = 0.3
const movement_speed = 10
const gravity = 20
const jump_velocity = 10

# Signals for placing/breaking blocks
signal place_block(pos, t) # t = type
signal break_block(pos)


# -----------------------
# --- Godot Functions ---
# -----------------------

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Lock the mouse to the game

func _input(event):
	if Input.is_action_just_pressed("Pause"):
		paused = not paused
		
		if paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if paused:
		return
	
	if event is InputEventMouseMotion:
		head.rotate_y(deg2rad(-event.relative.x * mouse_sense))
		
		var delta_x = event.relative.y * mouse_sense
		if camera_x_rotation + delta_x > -90 and camera_x_rotation + delta_x < 90:
			camera.rotate_x(deg2rad(-delta_x))
			camera_x_rotation += delta_x

func _process(delta):
	pass

func _physics_process(delta):
	if paused:
		return
		
	var basis = head.get_global_transform().basis
	
	var direction = Vector3()
	
	if Input.is_action_pressed("Forward"):
		direction -= basis.z
	if Input.is_action_pressed("Backward"):
		direction += basis.z
	
	if Input.is_action_pressed("Left"):
		direction -= basis.x
	if Input.is_action_pressed("Right"):
		direction += basis.x
	
	velocity.z = direction.z * movement_speed
	velocity.x = direction.x * movement_speed
	
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_velocity
	
	velocity.y -= gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)
	
	# Respawn the player cuz this game is buggy as shit
	if Input.is_action_just_pressed("respawn"):
		self.global_transform = starting_pos
	
	
	# Raycast for breaking/placing blocks
	if raycast.is_colliding():
		# The collision point is going to be on the surface of the block.
		# so this takes a half step into the block
		var norm = raycast.get_collision_normal()
		var pos = raycast.get_collision_point() - norm * 0.5
		
		# Calculate the actual position of the block here
		var bx = floor(pos.x) + 0.5
		var by = floor(pos.y) + 0.5
		var bz = floor(pos.z) + 0.5
		var bpos = Vector3(bx, by, bz) - self.translation
		
		# Set the block outline to be visible and at the block's position
		block_outline.translation = bpos
		block_outline.visible = true
		
		if Input.is_action_just_pressed("Break"):
			emit_signal("break_block", pos)
		if Input.is_action_just_pressed("Place"):
			emit_signal("place_block", pos + norm, Global.STONE)
	else:
		block_outline.visible = false

