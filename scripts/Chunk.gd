extends StaticBody
tool

# Defines the verticies of a cube
const vertices = [
	Vector3(0, 0, 0), #0
	Vector3(1, 0, 0), #1
	Vector3(0, 1, 0), #2
	Vector3(1, 1, 0), #3
	Vector3(0, 0, 1), #4
	Vector3(1, 0, 1), #5
	Vector3(0, 1, 1), #6
	Vector3(1, 1, 1)  #7
]

# Defines the faces of a cube
const TOP = [2, 3, 7, 6]
const BOTTOM = [0, 4, 5, 1]
const LEFT = [6, 4, 0, 2]
const RIGHT = [3, 1, 5, 7]
const FRONT = [7, 5, 4, 6]
const BACK = [2, 0, 1, 3]

# Array of block data for all blocks in the chunk
var blocks = []

var st = SurfaceTool.new() 		# Lets us create a mesh
var mesh = null					# The mesh to create
var mesh_instance = null		# Displays the mesh

# Preload the block material
var material = preload("res://assets/new_spatialmaterial.tres")

# Saves the chunk position variable for the terrain generation
var chunk_position = Vector2() setget set_chunk_position

# Create a new OpenSimplexNoise object for terrain generation.
var noise = OpenSimplexNoise.new()

# Just the built in ready function
func _ready():
	material.albedo_texture.set_flags(2) # Godot's DDS importer doesn't save when filter is turned off so this line manually does it
	generate() # Generates the blocks before we update the mesh
	update() # Runs the update function when the chunk is first loaded

# Actually adds values to the blockdata(blocks) array
func generate():
	# Loops through each block in the array and resizes it before filling in the block data
	blocks = []
	blocks.resize(Global.DIMENSION.x)
	for i in range(0, Global.DIMENSION.x):
		blocks[i] = []
		blocks[i].resize(Global.DIMENSION.y)
		for j in range(0, Global.DIMENSION.y):
			blocks[i][j] = []
			blocks[i][j].resize(Global.DIMENSION.z)
			for k in range(0, Global.DIMENSION.z):
				# Gets the specific position of a block | Will be used to sample from the OpenSimplexNoise
				var global_pos = chunk_position * \
					Vector2(Global.DIMENSION.x, Global.DIMENSION.z) + \
					Vector2(i, k)
				
				# Gets the height of the block and normalize it.
				# Then multiply by the y size of the chunk so it will be between the minimum and maximum block height
				var height = int((noise.get_noise_2dv(global_pos) + 1) / 2 * Global.DIMENSION.y)
				
				# Sets the block type to air so we don't have to manually tell it what is and isn't air
				var block = Global.AIR
				
				# Sets the block type based on the block's height
				if j < height / 2:
					block = Global.STONE
				elif j < height:
					block = Global.DIRT
				elif j == height:
					block = Global.GRASS
				
				# Actually sets the block type
				blocks[i][j][k] = block

# Updates the chunk
func update():
	# Unload the chunk if it's already loaded in
	if mesh_instance != null:
		mesh_instance.call_deferred("queue_free")
		mesh_instance = null
		
	# Load the mesh
	mesh = Mesh.new()						# Create the mesh
	mesh_instance = MeshInstance.new()		# Create mesh instance
	st.begin(mesh.PRIMITIVE_TRIANGLES)		# Sets up ST to create mesh using triangles
	
	# Loop through the entire chunk and create the blocks
	for x in Global.DIMENSION.x:
		for y in Global.DIMENSION.y:
			for z in Global.DIMENSION.z:
				create_block(x, y, z)
	
	st.generate_normals(false) 		# Generate normals
	st.set_material(material)		# Sets the mesh's material
	st.commit(mesh)					# Commit the changes to the mesh
	mesh_instance.set_mesh(mesh)	# Set the mesh_instance to have the mesh
	
	add_child(mesh_instance) 					# Adds the mesh_instance as a child of the chunk
	mesh_instance.create_trimesh_collision()	# Creates the collisons for the mesh instance
	
	# Unhide self after updating the chunk
	self.visible = true

# Checks if a given block is transparent so Godot doesn't have to render a million faces
func check_transparent(x, y, z):
	# Checks if the x y and z is in bounds, if it is, we check if the block is transparent
	if x >= 0 and x < Global.DIMENSION.x and \
		y >= 0 and y < Global.DIMENSION.y and \
		z >= 0 and z < Global.DIMENSION.z:
			return not Global.types[blocks[x][y][z]][Global.SOLID]
	return true

# Creates the block at the specified 3d position
func create_block(x, y, z):
	var block = blocks[x][y][z] # Gets the block type at the given coordinate
	if block == Global.AIR:
		return					# If the block is air then no mesh needs to be rendered
	
	var block_info = Global.types[block] # Gets the blockdata for things like the texture_atlas_offset
	
	# Checks the visibility of each face before creating them
	if check_transparent(x, y + 1, z):
		create_face(TOP, x, y, z, block_info[Global.TOP])
	
	if check_transparent(x, y - 1, z):
		create_face(BOTTOM, x, y, z, block_info[Global.BOTTOM])
	
	if check_transparent(x - 1, y, z):
		create_face(LEFT, x, y, z, block_info[Global.LEFT])
		
	if check_transparent(x + 1, y, z):
		create_face(RIGHT, x, y, z, block_info[Global.RIGHT])
		
	if check_transparent(x, y, z - 1):
		create_face(BACK, x, y, z, block_info[Global.BACK])
		
	if check_transparent(x, y, z + 1):
		create_face(FRONT, x, y, z, block_info[Global.FRONT])

	
# Creates the specified face at the block's 3d position
func create_face(i, x, y, z, texture_atlas_offset):
	# Defines where each corner of the face is located
	var offset = Vector3(x, y, z)
	var a = vertices[i[0]] + offset
	var b = vertices[i[1]] + offset
	var c = vertices[i[2]] + offset
	var d = vertices[i[3]] + offset

	# Calculate texture UVs | The texture_atlas_offset is a number between 0 and 2
	var uv_offset = texture_atlas_offset / Global.TEXTURE_ATLAS_SIZE		# Normalizes the texture_atlas_offset
	var height = 1.0 / Global.TEXTURE_ATLAS_SIZE.y			# Normalizes the texture height
	var width = 1.0 / Global.TEXTURE_ATLAS_SIZE.x			# Normalizes the texture width

	# Gets the UV locations for the corners of the mesh
	# Using uv_offset means it starts at the top corner of the mesh

	var uv_a = uv_offset + Vector2(0, 0)			# Top Left
	var uv_b = uv_offset + Vector2(0, height)		# Bottom Left
	var uv_c = uv_offset + Vector2(width, height)	# Bottom Right
	var uv_d = uv_offset + Vector2(width, 0)		# Top Right

	st.add_triangle_fan(([a, b, c]), ([uv_a, uv_b, uv_c])) # These together
	st.add_triangle_fan(([a, c, d]), ([uv_a, uv_c, uv_d])) # an entire square

# chunk_position setter function
func set_chunk_position(pos):
	chunk_position = pos
	translation = Vector3(pos.x, 0, pos.y) * Global.DIMENSION
	
	# Briefly hide self when the chunk position is changed
	self.visible = false
