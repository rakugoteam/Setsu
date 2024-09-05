extends PanelContainer
class_name CharacterComp

@onready var ref_input := %IDEdit
@onready var display_input := %DisEdit

var root_node: RootNodePanel
var id := -1

func _to_dict():
	return {
		"Reference": ref_input.text,
		"DisplaySpeakerName": display_input.text,
		"ID": id
	}

func _from_dict(dict):
	ref_input.text = dict.get("Reference")
	display_input.text = dict.get("DisplaySpeakerName")
	id = dict.get("ID")

func _on_delete_pressed():
	queue_free()
	root_node.update_speakers()
