extends PanelContainer


@onready var ref_input = $MarginContainer/HBoxContainer2/LineEdit

var root_node
var id = -1


func _to_dict():
	return {
		"Reference": ref_input.text,
		"ID": id
	}


func _from_dict(dict):
	ref_input.text = dict.get("Reference")
	id = dict.get("ID")


func _on_delete_pressed():
	queue_free()
	root_node.update_speakers()
