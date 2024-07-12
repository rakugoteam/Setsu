@icon("res://Assets/Icons/NodesIcons/Root.svg")

class_name RootNodePanel
extends VBoxContainer

var file_dialog : FileDialog

@onready
var line_edit_db := $DataBaseContainer/LineEditDB

@onready
var character_node = preload("res://Objects/SubComponents/Character.tscn")
@onready
var characters_container = $CharactersMainContainer/CharactersContainer

@onready
var variable_node = preload("res://Objects/SubComponents/Variable.tscn")
@onready
var variables_container = $VariablesMainContainer/VariablesContainer

var graph_node
var id = ""
var db_file = ""

func _ready():
	for character in graph_node.get_parent().speakers:
		add_character(character.get("Reference"))
	
	for variable in graph_node.get_parent().variables:
		add_variable(true, variable)

func _from_dict(dict):
	id = dict.get("ID")


func add_character(reference: String = ""):
	var new_node = character_node.instantiate()
	characters_container.add_child(new_node)
	
	var node_id = characters_container.get_children().find(new_node)
	var ref_input: LineEdit = new_node.ref_input
	
	ref_input.text = reference
	ref_input.text_changed.connect(text_submitted_callback)
	new_node.id = node_id
	new_node.root_node = self
	
	update_speakers()


func add_variable(init: bool = false, dict: Dictionary = {}):
	var new_node = variable_node.instantiate()
	new_node.update_callback = update_variables
	variables_container.add_child(new_node)
	
	if init: # Called from _ready()
		new_node.name_input.text = dict.get("Name")
		
		match dict.get("Type"):
			"Boolean":
				new_node.type_selection.select(0)
				new_node.boolean_edit.button_pressed = dict.get("Value")
			"Integer":
				new_node.type_selection.select(1)
				new_node.number_edit.value = dict.get("Value")
			"String":
				new_node.type_selection.select(2)
				new_node.string_edit.text = dict.get("Value")
	
		new_node.update_value_edit()


## Call the update_speakers function when a character node is updated
func text_submitted_callback(_new_text):
	update_speakers()


## Update the GraphEdit speakers variable based on all character nodes
func update_speakers():
	var all_nodes = characters_container.get_children()
	var updated_speakers = []
	
	for child in all_nodes:
		if child.is_queued_for_deletion():
			continue
		
		child.id = all_nodes.find(child)
		
		updated_speakers.append(child._to_dict())
		
	graph_node.get_parent().speakers = updated_speakers


## Update the GraphEdit variables variable based on all variables nodes
func update_variables():
	var all_nodes = variables_container.get_children()
	var updated_variables = []
	
	for child in all_nodes:
		if child.is_queued_for_deletion():
			continue
		
		updated_variables.append(child._to_dict())
		
	graph_node.get_parent().variables = updated_variables

func _on_save_db_pressed():
	file_dialog = $FileDialogSave
	file_dialog.popup_centered()

func _on_load_db_pressed():
	file_dialog = $FileDialogOpen
	file_dialog.popup_centered()

func _on_file_dialog_file_selected(path):
	match file_dialog.mode:
		FileDialog.FILE_MODE_SAVE_FILE:
			var data = JSON.stringify(db_to_dict(), "\t", false, true)
			var file = FileAccess.open(path, FileAccess.WRITE)
			shorten_db_path(db_file)
			line_edit_db.text = db_file
			file.store_string(data)
			file.close()
		
		FileDialog.FILE_MODE_OPEN_FILE:
			load_db(path)


func shorten_db_path(path:String):
	db_file = path
	var monologue_json : String = graph_node.get_parent().file_path
	var monologue_base_dir = monologue_json.get_base_dir()
	if db_file.begins_with(monologue_base_dir):
		db_file = path.lstrip(monologue_base_dir + "/")

func load_db(path):
	if not FileAccess.file_exists(path):
		return
	
	shorten_db_path(path)
	line_edit_db.text = db_file
	var file := FileAccess.get_file_as_string(path)
	var data := JSON.parse_string(file) as Dictionary
	# print(data)
	db_from_dict(data)

func _on_line_edit_db_text_submitted(new_text):
	load_db(new_text)

func db_to_dict():
	return {
		"Characters": 
			graph_node.get_parent().speakers,
		"Variables":
		graph_node.get_parent().variables,
	}

func db_from_dict(dict:Dictionary):
	for ch in characters_container.get_children():
		ch.queue_free()
	
	for ch in variables_container.get_children():
		ch.queue_free()

	graph_node.get_parent().speakers = dict["Characters"]
	graph_node.get_parent().variables = dict["Variables"]

	for character in graph_node.get_parent().speakers:
		add_character(character.get("Reference"))
	
	for variable in graph_node.get_parent().variables:
		add_variable(true, variable)
