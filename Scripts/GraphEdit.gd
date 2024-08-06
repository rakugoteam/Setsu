extends GraphEdit


@onready var close_button = preload("res://Objects/SubComponents/CloseButton.tscn")

var file_path: String
var db_file_path: String

var speakers = []
var variables = []
var mouse_pressed = false
var selection_mode = false
var selected_nodes: Array[Node] = []

var data: Dictionary

var control_node

func get_connected_nodes(node: GraphNode, nodes: Array[Node]) -> Array:
	var connections := []
	for fid in node.get_output_port_count():
		for n in nodes:
			if n == node: continue
			for tid in n.get_input_port_count():
				if is_node_connected(node.name, fid, n.name, tid):
					connections.append([fid, node, tid])
	return connections

func _input(event):
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.is_pressed() and key.key_label == KEY_DELETE:
			if !selected_nodes: return
			for node in selected_nodes:
				if node.node_type != "RootNode":
					free_graphnode(node)

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

func get_free_bridge_number(_n = 1, lp_max = 50):
	for node in get_children():
		if (node.node_type in ["NodeBridgeOut", "NodeBridgeIn"]
			and node.number_selector.value == _n):
			if lp_max <= 0:
				return _n
				
			return get_free_bridge_number(_n + 1, lp_max - 1)
	return _n

func is_option_node_exciste(node_id):
	for node in get_children():
		if node.node_type != "NodeChoice":
			continue
		var node_options_id: Array = node.get_all_options_id()
		if node_options_id.has(node_id):
			return true
	return false

func _on_node_selected(node):
	if node in selected_nodes:
		set_selected(node)
		return

	selected_nodes.append(node)

func _on_node_deselected(node):
	if node not in selected_nodes: return
	var id := selected_nodes.find(node)
	selected_nodes.remove_at(id)

func free_graphnode(node: GraphNode):
	control_node.side_panel_node.hide()
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
	
	if node in selected_nodes:
		var id := selected_nodes.find(node)
		selected_nodes.remove_at(id)

	node.queue_free()

func _on_child_entered_tree(node: Node):
	if node is RootNode or not node is GraphNode:
		return
	
	var node_header = node.get_children(true)[0]
	var close_btn: TextureButton = close_button.instantiate()
	close_btn.connect("pressed", free_graphnode.bind(node))
	node_header.add_child(close_btn)

func shorten_db_path(path: String):
	db_file_path = path
	var monologue_json: String = file_path
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
		var monologue_json: String = file_path
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

func db_from_dict(dict: Dictionary):
	speakers = dict["Characters"]
	var id := 0
	for ch in speakers:
		ch["ID"] = id
		id += 1
	
	variables = dict["Variables"]

func _on_duplicate_nodes_request():
	if selected_nodes.size() != 1:
		await control_node.alert("Duplicating works only for 1 node at one time :(")
		return

	var node := selected_nodes[0] as MonologueGraphNode
	if node is RootNode:
		await control_node.alert("You can't duplicate RootNode")
		return

	var node_data := node._to_dict() as Dictionary
	if !node_data:
		await control_node.alert("You can't duplicate this node node_type: %s" % node.node_type)
		return
	
	var node_type := node_data["$type"] as String
	node_type = node_type.trim_prefix("Node")
	var dup := control_node.add_node(node_type) as MonologueGraphNode
	if !dup:
		await control_node.alert("You can't duplicate this node node_type: %s" % node_data["$type"])
		return
	
	var dup_data := dup._to_dict() as Dictionary
	match node_type:
		"Sentence":
			dup_data["Sentence"] = node_data["Sentence"]
			dup_data["SpeakerID"] = node_data["SpeakerID"]

		"Choice":
			var options := control_node.get_options_nodes(
				node_data["OptionsID"]) as Array
			for op in options:
				var duo_op := op.duplicate() as Dictionary
				duo_op.id = UUID.v4()
				data["ListNodes"].append(duo_op)
				dup.options.append(duo_op)
				dup_data["OptionsID"].append(duo_op.id)
				print("dup choidce")
			
		"DiceRoll":
			dup["Skill"] = node_data["Skill"]
			dup["Target"] = node_data["Target"]
			
		"Event", "Condition":
			dup["Condition"] = node_data["Condition"]

		"Action":
			dup_data["Action"] = node_data["Action"]

		"EndPath":
			dup_data["NextStoryName"] = node_data["NextStoryName"]
			
		"Comment":
			dup_data["Comment"] = node_data["Comment"]
		
		"BridgeIn", "BridgeOut":
			dup_data["NumberSelector"] = node_data["NumberSelector"]
		
		_:
			await control_node.alert("You duplicate not supported node_type: %s" % node_data["$type"])

	dup._from_dict(dup_data)
	set_selected(dup)
