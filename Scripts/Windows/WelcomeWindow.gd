extends Window

@onready var sep := $PanelContainer/CenterContainer/VBoxContainer2/HBoxContainer/VSeparator
@onready var uplaod_btn := $PanelContainer/CenterContainer/VBoxContainer2/HBoxContainer/UploadFileBtn

func _ready():
	$PanelContainer/VersionLabel.text = "v" + ProjectSettings.get("application/config/version")
	if OS.get_name().to_lower() != "web":
		sep.queue_free()
		uplaod_btn.queue_free()

func _on_control_resized():
	move_to_center()
