@icon("res://Assets/Icons/NodesIcons/Root.svg")

class_name RootNodePanel
extends VBoxContainer

var file_dialog: FileDialog

@onready
var line_edit_db := $DataBaseContainer/LineEditDB
@onready var upload_btn := $DataBaseContainer/UploadDB

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
		add_character(character.get("Reference"), character["DisplaySpeakerName"])
	
	for variable in graph_node.get_parent().variables:
		add_variable(true, variable)
	
	line_edit_db.text = graph_node.get_parent().db_file_path
	if OS.get_name().to_lower() == "web":
		line_edit_db.text = line_edit_db.text.trim_prefix("user://")
	else:
		upload_btn.hide()

func _from_dict(dict):
	id = dict.get("ID")

func add_character(reference := "", display_speaker_name := ""):
	var new_node: CharacterComp = character_node.instantiate()
	characters_container.add_child(new_node)
	
	var node_id = characters_container.get_children().find(new_node)
	var ref_input: LineEdit = new_node.ref_input
	var display_input: LineEdit = new_node.display_input
	
	ref_input.text = reference
	display_input.text = display_speaker_name
	ref_input.text_changed.connect(text_submitted_callback)
	display_input.text_changed.connect(text_submitted_callback)

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
	if OS.get_name().to_lower() == "web":
		file_dialog.access = FileDialog.ACCESS_USERDATA
	file_dialog.popup_centered()

func _on_load_db_pressed():
	file_dialog = $FileDialogOpen
	if OS.get_name().to_lower() == "web":
		file_dialog.access = FileDialog.ACCESS_USERDATA
	file_dialog.popup_centered()

func _on_file_dialog_file_selected(path):
	match file_dialog.mode:
		FileDialog.FILE_MODE_SAVE_FILE:
			graph_node.get_parent().save_db(path)
			
		FileDialog.FILE_MODE_OPEN_FILE:
			graph_node.get_parent().load_db(path)
			for ch in characters_container.get_children():
				ch.queue_free()
			
			for ch in variables_container.get_children():
				ch.queue_free()
			
			for character in graph_node.get_parent().speakers:
				add_character(character.get("Reference"))
			
			for variable in graph_node.get_parent().variables:
				add_variable(true, variable)

	line_edit_db.text = graph_node.get_parent().db_file_path
	if OS.get_name().to_lower() == "web":
		line_edit_db.text = line_edit_db.text.trim_prefix("user://")

func _on_line_edit_db_text_submitted(new_text: String):
	if OS.get_name().to_lower() == "web":
		new_text = "user://" + new_text
	graph_node.get_parent().load_db(new_text)

func _on_upload_db_pressed():
	var c = graph_node.get_parent().control_node
	c.upload_mode = "db"
	c.html_file_dialogue.show()
