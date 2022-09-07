extends Spatial

# Preload chunk scene
onready var chunk_scene = preload("res://scenes/Chunk.tscn")

# Get the node where chunks will be loaded
onready var chunks = $Chunks

# Get the player node
onready var player = $Player

# The distance which chunks will load at (in chunks)
var load_radius = 5

# Terrain generation is going to be handled on a separate thread
var load_thread = Thread.new()


func _ready():
	# Initialize chunks
	for i in range(0, load_radius):
		for j in range(0, load_radius):
			var chunk = chunk_scene.instance()
			chunk.set_chunk_position(Vector2(i, j))
			chunks.add_child(chunk)	
	
	# Start up the chunk loading thread
	load_thread.start(self, "_thread_process", null)
	
	# Connect Breaking/Placing signals
	player.connect("place_block", self, "_on_Player_place_block")
	player.connect("break_block", self, "_on_Player_break_block")

# Create a method for the thread to use | _userdata won't be used, so it has an underscore in front of it so Godot shuts up
func _thread_process(_userdata):
	while(true): # Infinite while loop (duh)
		for c in chunks.get_children(): # Loop through each loaded chunk
			var cx = c.chunk_position.x # Get the chunk positon (next line too)
			var cz = c.chunk_position.y # cz is intentionally referencing the y because the chunk position is a Vector2 and we're working in 3d
			
			# Get the chunk position of the player | floor turns it into an int
			var px = floor(player.translation.x / Global.DIMENSION.x)
			var pz = floor(player.translation.z / Global.DIMENSION.z)
			
			# Define the new position chunks should move to if they're outside the load radius
			var new_x = posmod(cx - px + load_radius / 2, load_radius) + px - load_radius / 2
			var new_z = posmod(cz - pz + load_radius / 2, load_radius) + pz - load_radius / 2
			
			# If the chunk positon isn't equal to the original position, move the chunk
			if (new_x != cx or new_z != cz):
				c.set_chunk_position(Vector2(int(new_x), int(new_z)))
				c.generate()
				c.update()

# Returns the chunk a position is in
# This is written really poorly because I just want to finish this
func get_chunk(chunk_pos):
	for c in chunks.get_children():
		if c.chunk_position == chunk_pos:
			return c
	return null


# Function run by the "place_block" signal
func _on_Player_place_block(pos, t):
	# Get the positions of the chunk the block will be in, then floor and normal it
	var cx = int(floor(pos.x / Global.DIMENSION.x))
	var cz = int(floor(pos.z / Global.DIMENSION.z))
	
	# Get the block position
	var bx = posmod(floor(pos.x), Global.DIMENSION.x)
	var by = posmod(floor(pos.y), Global.DIMENSION.y)
	var bz = posmod(floor(pos.z), Global.DIMENSION.z)
	
	# Get the chunk the block will be added to
	var c = get_chunk(Vector2(cx, cz))
	
	# If the chunk isn't null, update the blockdata
	if c != null:
		c.blocks[bx][by][bz] = t
		c.update()

# Function run by the "place_block" signal
# Literally just runs place block but sets it to air
func _on_Player_break_block(pos):
	_on_Player_place_block(pos, Global.AIR)
