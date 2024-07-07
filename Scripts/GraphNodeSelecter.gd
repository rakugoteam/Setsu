extends Window

@export var control_node : Control

func _ready():
	hide()

func _on_sentence_selector_pressed():
	control_node.add_node("Sentence")

func _on_choice_selector_pressed():
	control_node.add_node("Choice")

func _on_dice_roll_selector_pressed():
	control_node.add_node("DiceRoll")

func _on_bridge_selector_pressed():
	control_node.add_node("Bridge")

func _on_condition_selector_pressed():
	control_node.add_node("Condition")

func _on_action_selector_pressed():
	control_node.add_node("Action")

func _on_end_path_selector_pressed():
	control_node.add_node("EndPath")
