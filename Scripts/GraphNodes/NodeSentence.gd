@icon("res://Assets/Icons/NodesIcons/Sentence.svg")
class_name SentenceNode
extends MonologueGraphNode

@onready var text_label = $MainContainer/TextLabelPreview

var loaded_text := ""
var sentence := ""
var speaker_id := 0


func _ready():
	node_type = "NodeSentence"
	title = node_type


func _to_dict() -> Dictionary:
	var next_id_node = get_parent().get_all_connections_from_slot(name, 0)
	
	return {
		"$type": node_type,
		"ID": id,
		"NextID": next_id_node[0].id if next_id_node else -1,
		"Sentence": sentence,
		"SpeakerID": speaker_id,
		"EditorPosition": {
			"x": position_offset.x,
			"y": position_offset.y
		}
	}

func _from_dict(dict: Dictionary):
	id = dict.get("ID")
	sentence = dict.get("Sentence")
	speaker_id = dict.get("SpeakerID")
	
	_update()
	
	position_offset.x = dict.EditorPosition.get("x")
	position_offset.y = dict.EditorPosition.get("y")

func _update(panel: SentenceNodePanel = null):
	if panel != null:
		sentence = panel.sentence
		speaker_id = panel.speaker_id
	
	text_label._text = sentence
