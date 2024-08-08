extends GraphEdit


@onready var close_button = preload("res://Objects/SubComponents/CloseButton.tscn")

@onready var option_reference = preload("res://Objects/SubComponents/OptionReference.tscn")

var file_path: String
var db_file_path: String

var speakers = []
var variables = []
var mouse_pressed = false
var selection_mode = false
var selected_nodes: Array[Node] = []
var removed_nodes: Dictionary = {}

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

func _gui_input(event):
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.is_pressed():
			if key.ctrl_pressed and key.key_label == KEY_Z:
				if removed_nodes.size() > 0:
					restore_node(removed_nodes.keys().back())
				return

			shortcut(event)

func shortcut(key: InputEventKey):
	if true in [
		key.ctrl_pressed,
		key.alt_pressed,
		key.shift_pressed,
	]: return
	
	match key.key_label:
		KEY_DELETE:
			if !selected_nodes: return
			for node in selected_nodes:
				if not node: return
				if node.node_type != "RootNode":
					free_graphnode(node)

		KEY_S:
			var gn: GraphNode = control_node.add_node("Sentence")
			try_connecting_from_selected(gn)

		KEY_C:
			var gn: GraphNode = control_node.add_node("Choice")
			try_connecting_from_selected(gn)

		KEY_D:
			var gn: GraphNode = control_node.add_node("DiceRoll")
			try_connecting_from_selected(gn)

		KEY_B:
			var gn: GraphNode = control_node.add_node("Bridge")
			try_connecting_from_selected(gn)

		KEY_N: control_node.add_node("Condition")
		KEY_A:
			var gn: GraphNode = control_node.add_node("Action")
			try_connecting_from_selected(gn)

		KEY_E:
			var gn: GraphNode = control_node.add_node("EndPath")
			try_connecting_from_selected(gn)
		
		KEY_1:
			var c: ChoiceNode = control_node.add_node("Choice")
			c.options.clear()
			c.gen_options([""])
			try_connecting_from_selected(c)

		KEY_V: control_node.add_node("Event")
		KEY_SLASH: control_node.add_node("Comment")
		

func try_connecting_from_selected(node: GraphNode):
	if selected_nodes.size() != 1: return
	var fnode := selected_nodes[0] as GraphNode
	connect_node(fnode.name, 0, node.name, 0)

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

func try_show_inspector(node):
	if selected_nodes == [node]:
		control_node.side_panel_node.show()

func _on_node_selected(node):
	if node in selected_nodes:
		set_selected(node)
		return

	selected_nodes.append(node)
	try_show_inspector(node)

func _on_node_deselected(node):
	if node not in selected_nodes: return
	var id := selected_nodes.find(node)
	selected_nodes.remove_at(id)
	try_show_inspector(node)

func disconnect_all(node, n) -> Array:
	var connections := []
	for co in get_connection_list():
		if (co.get("from_node") == node.name
			and co.get("to_node") == n.name):
			disconnect_node(
				co.get("from_node"), co.get("from_port"),
				co.get("to_node"), co.get("to_port")
			)
		connections.append([
			co.get("from_node"), co.get("from_port"),
			co.get("to_node"), co.get("to_port")
		])
	return connections

func restore_node(node: GraphNode):
	var connections := removed_nodes[node] as Array
	removed_nodes.erase(node)
	node.show()

	for co in connections:
		connect_node(co[0], co[1], co[2], co[3])

func free_graphnode(node: GraphNode):
	control_node.side_panel_node.hide()
	# Disconnect all empty connections
	var connections := []
	for n in get_all_connections_to_node(node.name):
		connections.append_array(disconnect_all(node, n))
		connections.append_array(disconnect_all(n, node))
	
	for n in get_all_connections_from_node(node.name):
		connections.append_array(disconnect_all(node, n))
		connections.append_array(disconnect_all(n, node))
	
	if node in selected_nodes:
		var id := selected_nodes.find(node)
		selected_nodes.remove_at(id)

	node.hide()
	removed_nodes[node] = connections

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
	
	var node_type := node.node_type as String
	node_type = node_type.trim_prefix("Node")
	var copy := control_node.add_node(node_type) as MonologueGraphNode
	if !copy:
		await control_node.alert("You can't duplicate this node node_type: %s" % node_type)
		return
	
	var copy_dict := copy._to_dict() as Dictionary
	var node_dict := node._to_dict() as Dictionary
	
	match node_type:
		"Sentence":
			var sentence_node := node as SentenceNode
			var sentence_copy := copy as SentenceNode
			sentence_copy.sentence = sentence_node.sentence
			sentence_copy.speaker_id = sentence_node.speaker_id
			copy_dict = sentence_copy._to_dict()

		"Choice":
			var choice_node := node as ChoiceNode
			var choice_copy := copy as ChoiceNode
			
			var options := []
			for op in choice_node.get_children():
				var option_ref := op as OptionReference
				options.append(option_ref.sentence)

			choice_copy.options.clear()
			choice_copy.gen_options(options)
			set_selected(copy)
			return

		"DiceRoll":
			var dice_roll_node := node as DiceRollNode
			var dice_roll_copy := copy as DiceRollNode
			dice_roll_copy.skill = dice_roll_node.skill
			dice_roll_copy.target_number = dice_roll_node.target_number
			copy_dict = dice_roll_copy._to_dict()
			
		"Event", "Condition":
			copy_dict["Condition"] = node_dict["Condition"]

		"Action":
			copy_dict["Action"] = node_dict["Action"]

		"EndPath":
			var end_path_node := node as EndPathNode
			var end_path_copy := copy as EndPathNode
			end_path_copy.next_story_name = end_path_node.next_story_name
			copy_dict = end_path_copy._to_dict()
			
		"Comment":
			var comment_node := node as CommentNode
			var comment_copy := copy as CommentNode
			comment_copy.comment_edit.text = comment_node.comment_edit.text
			copy_dict = comment_copy._to_dict()
		
		"BridgeIn", "BridgeOut":
			copy_dict["NumberSelector"] = node_dict["NumberSelector"]
		
		_:
			await control_node.alert("You duplicate not supported node_type: %s" % node_dict["$type"])

	copy._from_dict(copy_dict)
	set_selected(copy)
