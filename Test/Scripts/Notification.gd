extends PanelContainer


@onready var timeleft := $VBoxContainer/TimeLeft
@onready var text_label := $VBoxContainer/MarginContainer/RichTextLabel


func _ready():
	hide()


func debug(text: String):
	show()
	text_label._text = "[color=e5b65e][DEBUG][/color] " + text
	timeleft.custom_minimum_size.x = size.x
	var tween = get_tree().create_tween()
	tween.tween_property(timeleft, "custom_minimum_size:x", 0, 7.5)
	tween.tween_callback(hide)
