extends Control

var dialog = {}
var dialog_for_localisation = []

@export var file_path: String

@onready var root_node = preload("res://Objects/GraphNodes/RootNode.tscn")
@onready var sentence_node = preload("res://Objects/GraphNodes/SentenceNode.tscn")
@onready var dice_roll_node = preload("res://Objects/GraphNodes/DiceRollNode.tscn")
@onready var choice_node = preload("res://Objects/GraphNodes/ChoiceNode.tscn")
@onready var end_node = preload("res://Objects/GraphNodes/EndPathNode.tscn")
@onready var bridge_in_node = preload("res://Objects/GraphNodes/BridgeInNode.tscn")
@onready var bridge_out_node = preload("res://Objects/GraphNodes/BridgeOutNode.tscn")
@onready var option_panel = preload("res://Objects/SubComponents/OptionNode.tscn")

@onready var graph_edit: GraphEdit = $VBoxContainer/Control/GraphEdit
@onready var saved_notification = $VBoxContainer/HBoxContainer/SavedNotification
@onready var graph_node_selecter = $GraphNodeSelecter

var live_dict: Dictionary

var initial_pos = Vector2(40,40)
var option_index = 0
var node_index = 0
var all_nodes_index = 0

var root_node_ref
var root_dict

var picker_mode: bool = false
var picker_from_node
var picker_from_port
var picker_position


func _ready():
	var new_root_node = root_node.instantiate()
	graph_edit.add_child(new_root_node)
	
	if not file_path.is_empty():
		$WelcomeWindow.show()
		
	$NoInteractions.show()


func _to_dict() -> Dictionary:
	var list_nodes = []
	
	for node in graph_edit.get_children():
		if node.is_queued_for_deletion():
			continue
		list_nodes.append(node._to_dict())
		if node.node_type == "NodeChoice":
			for child in node.get_children():
				list_nodes.append(child._to_dict())
	
	root_dict = get_root_dict(list_nodes)
	root_node_ref = get_root_node_ref()
	
	var characters = graph_edit.speakers
	if graph_edit.speakers.size() <= 0:
		characters.append({
			"Reference": "_NARRATOR",
			"ID": 0
		})
	
	return {
		"RootNodeID": root_dict.get("ID"),
		"ListNodes": list_nodes,
		"Characters": characters,
		"Variables": root_node_ref.get_variables()
	}


func file_selected(path, open_mode):
	$NoInteractions.hide()
	
	file_path = path
	$WelcomeWindow.hide()
	if open_mode == 0: #NEW
		save()
		
	load_project(path)


func get_root_dict(nodes):
	for node in nodes:
		if node.get("$type") == "NodeRoot":
			return node


func get_root_node_ref():
	for node in graph_edit.get_children():
		if !node.is_queued_for_deletion() and node.id == root_dict.get("ID"):
			return node


func save():
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	var data = JSON.stringify(_to_dict(), "\t", false, true)
	file.store_string(data)
	file.close()
	
	saved_notification.show()
	await get_tree().create_timer(1.5).timeout
	saved_notification.hide()


func load_project(path):
	assert(FileAccess.file_exists(path))
	
	var file = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(file)
	
	live_dict = data
	graph_edit.speakers = data.get("Characters")
	
	for node in graph_edit.get_children():
		node.queue_free()
	graph_edit.clear_connections()
	
	var node_list = data.get("ListNodes")
	root_dict = get_root_dict(node_list)
	
	for node in node_list:
		var new_node
		match node.get("$type"):
			"NodeRoot":
				new_node = root_node.instantiate()
			"NodeSentence":
				new_node = sentence_node.instantiate()
			"NodeChoice":
				new_node = choice_node.instantiate()
			"NodeDiceRoll":
				new_node = dice_roll_node.instantiate()
			"NodeEndPath":
				new_node = end_node.instantiate()
			"NodeBridgeIn":
				new_node = bridge_in_node.instantiate()
			"NodeBridgeOut":
				new_node = bridge_out_node.instantiate()
		
		if not new_node:
			continue
		new_node.id = node.get("ID")
		
		graph_edit.add_child(new_node)
		if node.get("$type") == "NodeRoot":
			new_node._from_dict(node, node_list)
		else:
			new_node._from_dict(node)
	
	for node in node_list.filter(func(n): return n.get("$type") == "NodeChoice"):
		var graph_node = get_node_by_id(node.get("ID"))
		graph_node._options_from_dict(node, node_list)
	
	# Root Node Variables
	for variable in data.get("Variables"):
		root_node_ref.add_variable()
	
	for node in node_list:
		if not node.has("ID"):
			continue
		
		var current_node = get_node_by_id(node.get("ID"))
		match node.get("$type"):
			"NodeRoot":
				if node.get("NextID") is String:
					var next_node = get_node_by_id(node.get("NextID"))
					graph_edit.connect_node(current_node.name, 0, next_node.name, 0)
			"NodeSentence":
				if node.get("NextID") is String:
					var next_node = get_node_by_id(node.get("NextID"))
					graph_edit.connect_node(current_node.name, 0, next_node.name, 0)
			"NodeChoice":
				current_node.connect_all_options(node_list)
			"NodeDiceRoll":
				if node.get("PassID") is String:
					var pass_node = get_node_by_id(node.get("PassID"))
					graph_edit.connect_node(current_node.name, 0, pass_node.name, 0)
				
				if node.get("FailID") is String:
					var fail_node = get_node_by_id(node.get("FailID"))
					graph_edit.connect_node(current_node.name, 1, fail_node.name, 0)
			"NodeBridgeOut":
				if node.get("NextID") is String:
					var next_node = get_node_by_id(node.get("NextID"))
					graph_edit.connect_node(current_node.name, 0, next_node.name, 0)
		
		if not current_node: # OptionNode
			continue
		
		if node.has("EditorPosition"):
			current_node.position_offset.x = node.EditorPosition.get("x")
			current_node.position_offset.y = node.EditorPosition.get("y")
			
	root_node_ref = get_root_node_ref()
	
	
func get_node_by_id(id):
	for node in graph_edit.get_children():
		if node.id == id:
			return node
	
func get_options_nodes(node_list, options_id):
	var options = []
	
	for node in node_list:
		if node.get("ID") in options_id:
			options.append(node)
	return options


###############################
#  New node buttons callback  #
###############################

func center_node_in_graph_edit(node):
	if picker_mode:
		node.position_offset = picker_position
		graph_edit.connect_node(picker_from_node, picker_from_port, node.name, 0)
		disable_picker_mode()
		return
	
	node.position_offset = ((graph_edit.size/2) + graph_edit.scroll_offset) / graph_edit.zoom

func _on_new_sentence_pressed():
	var node = sentence_node.instantiate()
	graph_edit.add_child(node)
	center_node_in_graph_edit(node)

func _on_NewOption_pressed():
	var node = choice_node.instantiate()
	graph_edit.add_child(node)
	node._on_created()
	center_node_in_graph_edit(node)

func _on_NewRoll_pressed():
	var node = dice_roll_node.instantiate()
	graph_edit.add_child(node)
	center_node_in_graph_edit(node)

func _on_new_end_pressed():
	var node = end_node.instantiate()
	graph_edit.add_child(node)
	center_node_in_graph_edit(node)

func _on_new_bridge_pressed():
	var number = graph_edit.get_free_bridge_number()
	
	var in_node = bridge_in_node.instantiate()
	var out_node = bridge_out_node.instantiate()
	
	graph_edit.add_child(in_node)
	graph_edit.add_child(out_node)
	
	in_node.number_selector.value = number
	out_node.number_selector.value = number
	
	center_node_in_graph_edit(in_node)
	center_node_in_graph_edit(out_node)

func _on_Clear_pressed():
	for node in get_tree().get_nodes_in_group("graph_nodes"):
		if node.node_type != "NodeRoot":
			node.queue_free()
	graph_edit.clear_connections()


func _on_GraphEdit_connection_request(from, from_slot, to, to_slot):
	if graph_edit.get_all_connections_from_slot(from, from_slot).size() <= 0:
		graph_edit.connect_node(from, from_slot, to, to_slot)

func _on_GraphEdit_disconnection_request(from, from_slot, to, to_slot):
	graph_edit.disconnect_node(from, from_slot, to, to_slot)



####################
#  File selection  #
####################

func _on_new_file_btn_pressed():
	var output = []
	OS.execute(
		"Powershell.exe",
		["\"Add-Type -AssemblyName System.Windows.Forms ; $SaveFileBrowser = New-Object System.Windows.Forms.SaveFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop') ; Filter = 'JSON file|*.json' } ; $null = $SaveFileBrowser.ShowDialog() ; return $SaveFileBrowser.FileName\""],
		output
	)
	
	var file_path = output[0].trim_suffix("\r\n")
	if file_path != "":
		return file_selected(file_path, 0)


func _on_open_file_btn_pressed():
	var output = []
	OS.execute(
		"Powershell.exe",
		["\"Add-Type -AssemblyName System.Windows.Forms ; $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop') ; Filter = 'JSON file|*.json' } ; $null = $FileBrowser.ShowDialog() ; return $FileBrowser.FileName\""],
		output
	)
	
	var file_path = output[0].trim_suffix("\r\n")
	if file_path != "":
		return file_selected(file_path, 1)


func _on_graph_edit_connection_to_empty(from_node, from_port, release_position):
	graph_node_selecter.position = get_viewport().get_mouse_position()
	graph_node_selecter.show()
	
	picker_from_node = from_node
	picker_from_port = from_port
	picker_position = (get_local_mouse_position() + graph_edit.scroll_offset) / graph_edit.zoom
	
	picker_mode = true
	$NoInteractions.show()


func disable_picker_mode():
	graph_node_selecter.hide()
	picker_mode = false
	$NoInteractions.hide()


func _on_graph_node_selecter_focus_exited():
	disable_picker_mode()


func _on_graph_node_selecter_close_requested():
	disable_picker_mode()
