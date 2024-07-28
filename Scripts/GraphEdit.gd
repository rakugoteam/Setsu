extends GraphEdit


@onready var close_button = preload("res://Objects/SubComponents/CloseButton.tscn")

var file_path: String
var db_file_path : String

var speakers = []
var variables = []
var mouse_pressed = false
var selection_mode = false

var graphnode_selected = false
var moving_mode = false

var data: Dictionary

var control_node

func _input(event):
	if event is InputEventMouseButton:
		mouse_pressed = event.is_pressed()
	
	selection_mode = false
	moving_mode = false
	if event is InputEventMouseMotion and mouse_pressed:
		selection_mode = true
		moving_mode = graphnode_selected

func get_all_connections_from_node(from_node: StringName):
	var connections = []
	
	for connection in get_connection_list():
		if connection.get("from_node") == from_node:
			var to = get_node_or_null(NodePath(connection.get("to_node")))
			connections.append(to)
	
	return connections

func get_all_connections_to_node(from_node: StringName):
	var connections = []
	
	for connection in get_connection_list():
		if connection.get("to_node") == from_node:
			var from = get_node_or_null(NodePath(connection.get("from_node")))
			connections.append(from)
	
	return connections

func get_all_connections_from_slot(from_node: StringName, from_port: int):
	var connections = []
	
	for connection in get_connection_list():
		if (connection.get("from_node") == from_node
			and connection.get("from_port") == from_port):
			var to = get_node_or_null(NodePath(connection.get("to_node")))
			connections.append(to)

	return connections

func get_linked_bridge_node(target_number):
	for node in get_children():
		if node.node_type == "NodeBridgeOut" and node.number_selector.value == target_number:
			return node

func get_free_bridge_number(_n=1, lp_max=50):
	for node in get_children():
		if (node.node_type in ["NodeBridgeOut", "NodeBridgeIn"]
			and node.number_selector.value == _n):
			if lp_max <= 0:
				return _n
				
			return get_free_bridge_number(_n+1, lp_max-1)
	return _n

func is_option_node_exciste(node_id):
	for node in get_children():
		if node.node_type != "NodeChoice":
			continue
		var node_options_id: Array = node.get_all_options_id()
		if node_options_id.has(node_id):
			return true
	return false

func _on_node_selected(_node):
	graphnode_selected = true

func _on_node_deselected(_node):
	graphnode_selected = false

func free_graphnode(node: GraphNode):
	# Disconnect all empty connections
	for n in get_all_connections_to_node(node.name):
		for co in get_connection_list():
			if (co.get("from_node") == n.name
				and co.get("to_node") == node.name):
				disconnect_node(co.get("from_node"), co.get("from_port"), co.get("to_node"), co.get("to_port"))
	
	for n in get_all_connections_from_node(node.name):
		for co in get_connection_list():
			if (co.get("from_node") == node.name
				and co.get("to_node") == n.name):
				disconnect_node(co.get("from_node"), co.get("from_port"), co.get("to_node"), co.get("to_port"))
		
	node.queue_free()

func _on_child_entered_tree(node: Node):
	if node is RootNode or not node is GraphNode:
		return
	
	var node_header = node.get_children(true)[0]
	var close_btn: TextureButton = close_button.instantiate()
	close_btn.connect("pressed", free_graphnode.bind(node))
	node_header.add_child(close_btn)

func shorten_db_path(path:String):
	db_file_path = path
	var monologue_json : String = file_path
	var monologue_base_dir = monologue_json.get_base_dir() + "/"
	if OS.get_name().to_lower() == "web":
		monologue_base_dir = monologue_base_dir.trim_prefix("user://")

	if db_file_path.begins_with(monologue_base_dir):
		db_file_path = path.trim_prefix(monologue_base_dir)

func save_db(path := db_file_path):
	var db = JSON.stringify(db_to_dict(), "\t", false, true)
	shorten_db_path(path)
	path = rel_db_path(path)
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(db)
	file.close()

func rel_db_path(path: String):
	if path.is_relative_path():
		var monologue_json : String = file_path
		var monologue_base_dir = monologue_json.get_base_dir()
		path = monologue_base_dir.path_join(path)
	
	return path

func load_db(path = db_file_path):
	shorten_db_path(path)
	path = rel_db_path(path)

	if not FileAccess.file_exists(path):
		await control_node.alert("file dont exist %s" % path)
		return

	# await control_node.alert("file exist: %s" % path)
	var file := FileAccess.get_file_as_string(path)
	var db := JSON.parse_string(file) as Dictionary
	# await control_node.alert(str(data))
	db_from_dict(db)
	# await control_node.alert(db_to_dict())

func db_to_dict():
	return {
		"Characters": speakers,
		"Variables": variables,
	}

func db_from_dict(dict:Dictionary):
	speakers = dict["Characters"]
	var id := 0
	for ch in speakers:
		ch["ID"] = id
		id += 1
	
	variables = dict["Variables"]
