extends Control

var upload_mode := "dialogue"
var dialog = {}
var dialog_for_localisation = []
var emoji_finder: Window
var icon_search: Window
var file_menu := false

const HISTORY_FILE_PATH: String = "user://history.save"
const emoji_finder_path := \
"res://addons/emojis-for-godot/EmojiPanel/EmojiPanel.tscn"
const icon_finder_script := \
	"res://addons/material-design-icons/icon_finder/IconFinder.tscn"

@onready var graph_edit_inst = preload("res://Objects/GraphEdit.tscn")
@onready var root_node = preload("res://Objects/GraphNodes/RootNode.tscn")
@onready var sentence_node = preload("res://Objects/GraphNodes/SentenceNode.tscn")
@onready var dice_roll_node = preload("res://Objects/GraphNodes/DiceRollNode.tscn")
@onready var choice_node = preload("res://Objects/GraphNodes/ChoiceNode.tscn")
@onready var end_node = preload("res://Objects/GraphNodes/EndPathNode.tscn")
@onready var bridge_in_node = preload("res://Objects/GraphNodes/BridgeInNode.tscn")
@onready var bridge_out_node = preload("res://Objects/GraphNodes/BridgeOutNode.tscn")
@onready var condition_node = preload("res://Objects/GraphNodes/ConditionNode.tscn")
@onready var action_node = preload("res://Objects/GraphNodes/ActionNode.tscn")
@onready var comment_node = preload("res://Objects/GraphNodes/CommentNode.tscn")
@onready var event_node = preload("res://Objects/GraphNodes/EventNode.tscn")
@onready var reroute_node = preload("res://Objects/GraphNodes/RerouteNode.tscn")
@onready var option_panel = preload("res://Objects/SubComponents/OptionNode.tscn")

@onready var recent_file_button = preload("res://Objects/SubComponents/RecentFileButton.tscn")

@onready var tab_bar: TabBar = $MarginContainer/MainContainer/GraphEditsArea/VBoxContainer/TabBar
@onready var graph_edits: TabContainer = $MarginContainer/MainContainer/GraphEditsArea/VBoxContainer/GraphEdits
@onready var side_panel_node := $MarginContainer/MainContainer/GraphEditsArea/MarginContainer/SidePanelNodeDetails
@onready var saved_notification := $MarginContainer/MainContainer/Header/SavedNotification
@onready var graph_node_selecter := $GraphNodeSelecter
@onready var save_progress_bar: ProgressBar = $MarginContainer/MainContainer/Header/SaveProgressBarContainer/SaveProgressBar
@onready var save_button: Button = $MarginContainer/MainContainer/Header/Save
@onready var test_button: Button = $MarginContainer/MainContainer/Header/TestBtnContainer/Test
@onready var add_menu_bar := $MarginContainer/MainContainer/Header/MenuBar/Add
@onready var recent_files_container := $WelcomeWindow/PanelContainer/CenterContainer/VBoxContainer2/RecentFilesContainer
@onready var recent_files_button_container := $WelcomeWindow/PanelContainer/CenterContainer/VBoxContainer2/RecentFilesContainer/ButtonContainer
@onready var cancel_file_btn := $WelcomeWindow/PanelContainer/CenterContainer/VBoxContainer2/HBoxContainer/CancelFileBtn
@onready var html_file_dialogue := $HTML5FileDialog
@onready var sync_menu := $MarginContainer/MainContainer/Header/MenuBar/Sync
@onready var edit_conf_btn := $MarginContainer/MainContainer/Header/TestBtnContainer/EditConfBtn

var live_dict: Dictionary

var initial_pos = Vector2(40, 40)
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
	get_current_graph_edit().add_child(new_root_node)
	connect_graph_edit_signal(get_current_graph_edit())

	if OS.get_name().to_lower() != "web":
		sync_menu.queue_free()
		html_file_dialogue.queue_free()

	icon_search = load(icon_finder_script).instantiate()
	icon_search.hide()
	add_child.call_deferred(icon_search)
	
	emoji_finder = load(emoji_finder_path).instantiate()
	emoji_finder.hide()
	add_child.call_deferred(emoji_finder)

	saved_notification.hide()
	save_progress_bar.hide()
	
	# Load recent files
	if not FileAccess.file_exists(HISTORY_FILE_PATH):
		FileAccess.open(HISTORY_FILE_PATH, FileAccess.WRITE)
		recent_files_container.hide()
	else:
		var file = FileAccess.open(HISTORY_FILE_PATH, FileAccess.READ)
		var raw_data = file.get_as_text()
		if raw_data:
			var data: Array = JSON.parse_string(raw_data)
			for path in data:
				if FileAccess.file_exists(path):
					continue
				data.erase(path)
			for path in data.slice(0, 3):
				var btn: Button = recent_file_button.instantiate()
				var btn_text = path
				btn_text = path.replace("\\", "/")
				btn_text = btn_text.replace("//", "/")
				btn_text = btn_text.split("/")
				
				if btn_text.size() >= 2:
					btn_text = btn_text.slice(-2, btn_text.size())
					btn_text = btn_text[0].path_join(btn_text[1])
				else:
					btn_text = btn_text.back()
				
				if OS.get_name().to_lower() == "web":
					btn_text = btn_text.trim_prefix("user:/")

				btn.text = btn_text
				btn.pressed.connect(file_selected.bind(path, 1))
				recent_files_button_container.add_child(btn)
			recent_files_container.show()
		else:
			recent_files_container.hide()
	
	$WelcomeWindow.show()
	$NoInteractions.show()

func _shortcut_input(event):
	if event.is_action_pressed("Save"):
		save(false)

func get_current_graph_edit() -> GraphEdit:
	return graph_edits.get_child(tab_bar.current_tab)

func get_graph_nodes() -> Array[Node]:
	return get_current_graph_edit().get_children()

func _to_dict() -> Dictionary:
	var list_nodes = []
	
	save_progress_bar.max_value = get_graph_nodes().size() + 1
	
	for node in get_graph_nodes():
		if node.is_queued_for_deletion():
			continue
		
		if node in get_current_graph_edit().removed_nodes:
			continue

		list_nodes.append(node._to_dict())
		if node.node_type == "NodeChoice":
			for child in node.get_children():
				list_nodes.append(child._to_dict())
		
		save_progress_bar.value = list_nodes.size()
	
	root_dict = get_root_dict(list_nodes)
	root_node_ref = get_root_node_ref()
	
	if get_current_graph_edit().db_file_path:
		save_progress_bar.max_value += 1
		save_progress_bar.value += 1
		get_current_graph_edit().save_db()
		save_progress_bar.value += 1

		var db_file_path: String = get_current_graph_edit().db_file_path
		if OS.get_name().to_lower() == "web":
			db_file_path = db_file_path.trim_prefix("user://")

		return {
			"EditorVersion": ProjectSettings.get_setting(
				"application/config/version", "unknown"),
			"RootNodeID": root_dict.get("ID"),
			"ListNodes": list_nodes,
			"DBFile": db_file_path,
		}

	var characters = get_current_graph_edit().speakers
	if get_current_graph_edit().speakers.size() <= 0:
		characters.append({
			"Reference": "_NARRATOR",
			"ID": 0
		})
	
	save_progress_bar.value += 1

	return {
		"EditorVersion": ProjectSettings.get_setting(
			"application/config/version", "unknown"),
		"RootNodeID": root_dict.get("ID"),
		"ListNodes": list_nodes,
		"Characters": characters,
		"Variables": get_current_graph_edit().variables
	}


func file_selected(path, open_mode):
	if not FileAccess.open(path, FileAccess.READ):
		return
	
	for ge in graph_edits.get_children():
		if not ge is GraphEdit:
			continue
		
		if ge.file_path == path:
			return
	
	$NoInteractions.hide()
	
	tab_bar.add_tab(path.get_file())
	tab_bar.move_tab(tab_bar.tab_count - 2, tab_bar.tab_count - 1)
	tab_bar.current_tab = tab_bar.tab_count - 2
	
	var graph_edit = get_current_graph_edit()
	graph_edit.control_node = self
	graph_edit.file_path = path
	
	$WelcomeWindow.hide()
	if open_mode == 0: # NEW
		for node in graph_edit.get_children():
			node.queue_free()
		var new_root_node = root_node.instantiate()
		graph_edit.add_child(new_root_node)
		await save(true)

	if not FileAccess.file_exists(HISTORY_FILE_PATH):
		FileAccess.open(HISTORY_FILE_PATH, FileAccess.WRITE)
	else:
		var file: FileAccess = FileAccess.open(HISTORY_FILE_PATH, FileAccess.READ_WRITE)
		var raw_data = file.get_as_text()
		var data: Array
		if raw_data:
			data = JSON.parse_string(raw_data)
			data.erase(path)
			data.insert(0, path)
		else:
			data = [path]
		for p in data:
			if FileAccess.file_exists(p):
				continue
			data.erase(p)
		file = FileAccess.open(HISTORY_FILE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(data.slice(0, 10)))
	
	load_project(path)

func get_root_dict(nodes):
	for node in nodes:
		if node.get("$type") == "NodeRoot":
			return node

func get_root_node_ref():
	for node in get_graph_nodes():
		if (!node.is_queued_for_deletion()
			and node.id == root_dict.get("ID")):
			return node

func save(quick: bool = false):
	save_progress_bar.value = 0
	save_progress_bar.show()
	save_button.hide()
	test_button.hide()
	
	var data = JSON.stringify(_to_dict(), "\t", false, true)
	if not data: # Fail to load
		save_progress_bar.hide()
		save_button.show()
		test_button.show()
	
	var file = FileAccess.open(
		get_current_graph_edit().file_path, FileAccess.WRITE)
	file.store_string(data)
	file.close()
	
	saved_notification.show()
	if !quick:
		await get_tree().create_timer(1.5).timeout
	saved_notification.hide()
	save_progress_bar.hide()
	save_button.show()
	test_button.show()

func alert(message: String):
	$AcceptDialog.dialog_text = message
	$AcceptDialog.show()
	await $AcceptDialog.confirmed

func load_project(path):
	if not FileAccess.file_exists(path):
		return
		
	$NoInteractions.hide()
	var graph_edit = get_current_graph_edit()
	
	var file := FileAccess.get_file_as_string(path)
	graph_edit.name = path.get_file().trim_suffix(".json")
	
	var data := {}
	data = JSON.parse_string(file)

	if not data:
		data = _to_dict()
		save(true)
	
	live_dict = data

	if "DBFile" in data:
		var db_file := data["DBFile"] as String
		# alert("DBFile: %s" % db_file)
		get_current_graph_edit().load_db(db_file)

	else:
		# alert("DBFile: null")
		graph_edit.speakers = data.get("Characters")
		graph_edit.variables = data.get("Variables")
	
	# alert("loaded db: %s" % graph_edit.db_to_dict())
	
	for node in graph_edit.get_children():
		node.queue_free()
	
	graph_edit.clear_connections()
	graph_edit.data = data
	
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
			"NodeCondition":
				new_node = condition_node.instantiate()
			"NodeAction":
				new_node = action_node.instantiate()
			"NodeComment":
				new_node = comment_node.instantiate()
			"NodeEvent":
				new_node = event_node.instantiate()
			"NodeReroute":
				new_node = reroute_node.instantiate()
		
		if not new_node: continue
		new_node.id = node.get("ID")
		
		graph_edit.add_child(new_node)
		new_node._from_dict(node)
	
	for node in node_list:
		if not node.has("ID"): continue
		
		var current_node = get_node_by_id(node.get("ID"))
		match node.get("$type"):
			"NodeRoot", "NodeSentence", "NodeBridgeOut", "NodeAction", "NodeEvent", "NodeReroute":
				if node.get("NextID") is String:
					var next_node = get_node_by_id(node.get("NextID"))
					graph_edit.connect_node(current_node.name, 0, next_node.name, 0)
			"NodeChoice":
				current_node._update()
			"NodeDiceRoll":
				if node.get("PassID") is String:
					var pass_node = get_node_by_id(node.get("PassID"))
					graph_edit.connect_node(current_node.name, 0, pass_node.name, 0)
				
				if node.get("FailID") is String:
					var fail_node = get_node_by_id(node.get("FailID"))
					graph_edit.connect_node(current_node.name, 1, fail_node.name, 0)
			"NodeCondition":
				if node.get("IfNextID") is String:
					var if_node = get_node_by_id(node.get("IfNextID"))
					graph_edit.connect_node(current_node.name, 0, if_node.name, 0)
				
				if node.get("ElseNextID") is String:
					var else_node = get_node_by_id(node.get("ElseNextID"))
					graph_edit.connect_node(current_node.name, 1, else_node.name, 0)
		
		# if OptionNode
		if not current_node: continue
		
		if node.has("EditorPosition"):
			current_node.position_offset.x = node.EditorPosition.get("x")
			current_node.position_offset.y = node.EditorPosition.get("y")
			
	root_node_ref = get_root_node_ref()
	
	if not root_node_ref:
		var new_root_node = root_node.instantiate()
		get_current_graph_edit().add_child(new_root_node)
		
		save(true)
		root_node_ref = get_root_node_ref()
	
func get_node_by_id(id):
	for node in get_graph_nodes():
		if node.id == id: return node
	return null
	
func get_options_nodes(options_id):
	var options = []
	
	for node in live_dict["ListNodes"]:
		if node.get("ID") in options_id:
			options.append(node)
	return options

###############################
#  New node buttons callback  #
###############################

func center_node_in_graph_edit(node):
	var graph_edit = get_current_graph_edit()
	if picker_mode:
		node.position_offset = picker_position
		graph_edit.connect_node(picker_from_node, picker_from_port, node.name, 0)
		disable_picker_mode()
		return
	
	node.position_offset = (
		(graph_edit.size / 2)
		+ graph_edit.scroll_offset
		) / graph_edit.zoom

func _on_add_id_pressed(id):
	var node_type = add_menu_bar.get_item_text(id)
	add_node(node_type)

func add_node(node_type) -> MonologueGraphNode:
	if node_type == "Bridge":
		var number = get_current_graph_edit().get_free_bridge_number()
	
		var in_node = bridge_in_node.instantiate()
		var out_node = bridge_out_node.instantiate()
		
		get_current_graph_edit().add_child(in_node)
		get_current_graph_edit().add_child(out_node)
		
		in_node.number_selector.value = number
		out_node.number_selector.value = number
		
		center_node_in_graph_edit(in_node)
		center_node_in_graph_edit(out_node)
		in_node.position_offset.x -= in_node.size.x / 2 + 10
		out_node.position_offset.x += out_node.size.x / 2 + 10
		
	var node
	match node_type:
		"Sentence":
			node = sentence_node
		"Choice":
			node = choice_node
		"DiceRoll":
			node = dice_roll_node
		"Condition":
			node = condition_node
		"Action":
			node = action_node
		"EndPath":
			node = end_node
		"Event":
			node = event_node
		"Comment":
			node = comment_node
		"BridgeIn":
			node = bridge_in_node
		"BridgeOut":
			node = bridge_out_node
		"Reroute":
			node = reroute_node
	
	if not node: return null
	node = node.instantiate()
	get_current_graph_edit().add_child(node)
	center_node_in_graph_edit(node)
	return node
	
func _on_graph_edit_connection_request(from, from_slot, to, to_slot):
	if get_current_graph_edit().get_all_connections_from_slot(from, from_slot).size():
		get_current_graph_edit().connect_node(from, from_slot, to, to_slot)

func _on_graph_edit_disconnection_request(from, from_slot, to, to_slot):
	get_current_graph_edit().disconnect_node(from, from_slot, to, to_slot)


func test_project(from_selected_node: bool = false):
	await save(true)
	
	var global_vars = get_node("/root/GlobalVariables")
	global_vars.test_path = get_current_graph_edit().file_path
	
	var test_instance = preload("res://Test/Menu.tscn")
	var test_scene = test_instance.instantiate()
	
	if from_selected_node:
		test_scene._from_node_id = side_panel_node.current_panel.id
	
	get_tree().root.add_child(test_scene)

####################
#  File selection  #
####################

func new_file_select():
	$FileDialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	if OS.get_name().to_lower() == "web":
		$FileDialog.access = FileDialog.ACCESS_USERDATA
	$FileDialog.title = "Create New File"
	$FileDialog.ok_button_text = "Create"
	$FileDialog.popup_centered()
	var new_file_path = await $FileDialog.file_selected

	if new_file_path:
		FileAccess.open(new_file_path, FileAccess.WRITE)
		return new_file_path
	
	return null

func open_file_select():
	$FileDialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	if OS.get_name().to_lower() == "web":
		$FileDialog.access = FileDialog.ACCESS_USERDATA
	$FileDialog.title = "Open File"
	$FileDialog.ok_button_text = "Open"
	$FileDialog.popup_centered()
	var open_file = await $FileDialog.file_selected
	if open_file: return open_file
	return null

func _on_graph_edit_connection_to_empty(from_node, from_port, _release_position):
	graph_node_selecter.position = get_viewport().get_mouse_position()
	graph_node_selecter.show()
	
	picker_from_node = from_node
	picker_from_port = from_port
	picker_position = (
		get_local_mouse_position()
		+ get_current_graph_edit().scroll_offset
		) / get_current_graph_edit().zoom
	
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

func tab_changed(idx):
	side_panel_node.hide()
	if get_current_tab_name() != "+":
		graph_edits.current_tab = idx
		return
	
	new_graph_edit()
	cancel_file_btn.show()
	$WelcomeWindow.show()
	$NoInteractions.show()

func connect_graph_edit_signal(graph_edit: GraphEdit) -> void:
	graph_edit.connect("connection_to_empty", _on_graph_edit_connection_to_empty)
	graph_edit.connect("connection_request", _on_graph_edit_connection_request)
	graph_edit.connect("disconnection_request", _on_graph_edit_disconnection_request)
	graph_edit.connect("node_selected", side_panel_node.on_graph_node_selected)
	graph_edit.connect("node_deselected", side_panel_node.on_graph_node_deselected)

func tab_close_pressed(tab):
	graph_edits.get_child(tab).queue_free()
	tab_bar.remove_tab(tab)
	tab_changed(tab)

func _on_file_id_pressed(id):
	file_menu = true
	match id:
		0: # Open file
			var new_file_path = await open_file_select()
			if new_file_path == null:
				return
				
			new_graph_edit()
			return await file_selected(new_file_path, 1)

		1: # New file
			var new_file_path = await new_file_select()
			if new_file_path == null:
				return
			
			new_graph_edit()
			return await file_selected(new_file_path, 0)
		
		2: # Save
			save()
			return

func new_graph_edit():
	var graph_edit: GraphEdit = graph_edit_inst.instantiate()
	var new_root_node = root_node.instantiate()
	
	graph_edit.name = "new"
	connect_graph_edit_signal(graph_edit)
	
	graph_edits.add_child(graph_edit)
	graph_edit.add_child(new_root_node)
	
	for ge in graph_edits.get_children():
		ge.visible = ge == graph_edit

func _on_new_file_btn_pressed():
	$WelcomeWindow.hide()
	var new_file_path = await new_file_select()
	if new_file_path == null:
		$WelcomeWindow.show()
		return
		
	return await file_selected(new_file_path, 0)

func _on_open_file_btn_pressed():
	$WelcomeWindow.hide()
	var new_file_path = await open_file_select()
	if new_file_path == null:
		$WelcomeWindow.show()
		return
		
	return await file_selected(new_file_path, 1)

func _on_help_id_pressed(id):
	match id:
		0:
			OS.shell_open("https://github.com/atomic-junky/Monologue/wiki")
		1:
			OS.shell_open("https://rakugoteam.github.io/advanced-text-docs/2.0/Markdown/")

func _on_file_dialog_canceled():
	if file_menu:
		file_menu = false
		return
	
	$WelcomeWindow.show()

func _on_cancel_file_btn_pressed():
	$WelcomeWindow.hide()
	$NoInteractions.hide()
	if get_current_tab_name() == "+":
		tab_bar.current_tab -= 1

func _on_emojis_btn_pressed():
	emoji_finder.popup_centered()

func _on_icons_btn_pressed():
	icon_search.popup_centered()

func get_current_tab_name() -> String:
	return tab_bar.get_tab_title(tab_bar.current_tab)

func download_dialogue():
	var data = JSON.stringify(_to_dict(), "\t", false, true)
	JavaScriptBridge.download_buffer(
		data.to_utf8_buffer(),
		get_current_tab_name(),
		"application/json"
	)

func download_db():
	var current_tab := get_current_graph_edit()
	var db: Dictionary = current_tab.db_to_dict()
	var db_data := JSON.stringify(db, "\t", false, true)
	var db_path: String = current_tab.db_file_path
	db_path = Array(db_path.split("/", false)).back()
	JavaScriptBridge.download_buffer(
		db_data.to_utf8_buffer(), db_path,
		"application/json"
	)

func _on_upload_file_btn_pressed():
	upload_mode = "dialogue"
	html_file_dialogue.show()

func upload_file(file: HTML5FileHandle) -> String:
	var text := await file.as_text()
	var cloud_file_path := "user://" + file.name
	var cloud_file = FileAccess.open(
		cloud_file_path, FileAccess.WRITE)
	cloud_file.store_string(text)
	cloud_file.close()
	return cloud_file_path

func _on_html_5_file_dialog_file_selected(file: HTML5FileHandle):
	$WelcomeWindow.hide()
	var current_tab := get_current_graph_edit()
	match upload_mode:
		"dialogue":
			new_graph_edit()
			file_selected(await upload_file(file), 1)
		"db":
			side_panel_node.hide()
			current_tab.load_db(await upload_file(file))
			side_panel_node.show_config()

func _on_sync_id_pressed(id: int):
	match id:
		0: # UploadDialogue
			upload_mode = "dialogue"
			html_file_dialogue.show()
		1: # Upload DB
			upload_mode = "db"
			html_file_dialogue.show()
		2: # Download Dialogue
			download_dialogue()
		3: # Download DB
			download_db()

func _on_edit_conf_btn_toggled(toggled_on):
	if toggled_on: side_panel_node.show_config()
	else: side_panel_node.hide()

func _on_node_selected(node):
	edit_conf_btn.button_pressed = (
		node.node_type == "NodeRoot"
	)

func _on_close_node_btn_pressed():
	edit_conf_btn.button_pressed = false
