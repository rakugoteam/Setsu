@icon("res://Assets/Icons/NodesIcons/Sentence.svg")
class_name SentenceNodePanel
extends MonologueNodePanel

@onready var character_drop_node: OptionButton = %CharacterDrop
@onready var sentence_edit_node: TextEdit = %TextEdit

var sentence := ""
var speaker_id := 0

func _ready():
	for speaker in graph_node.get_parent().speakers:
		character_drop_node.add_item(speaker.get("Reference"), speaker.get("ID"))

func _from_dict(dict):
	id = dict.get("ID")
	sentence = dict.get("Sentence")
	speaker_id = dict.get("SpeakerID")
	
	if speaker_id: character_drop_node.select(speaker_id)
	else: graph_node.speaker_id = 0
	
	sentence_edit_node.text = sentence

func _on_sentence_text_edit_changed():
	sentence = sentence_edit_node.text
	graph_node.sentence = sentence
	
	change.emit(self)

func _on_character_drop_item_selected(index):
	speaker_id = index
	graph_node.speaker_id = index
	
	change.emit(self)
