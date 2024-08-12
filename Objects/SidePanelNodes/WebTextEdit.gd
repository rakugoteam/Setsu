extends TextEdit
class_name WebTextEdit

func _paste(caret_index):
	var paste_this := DisplayServer.clipboard_get()
	if OS.get_name().to_lower() == "web":
		var prompt := HTML5InputDialog.new()
		prompt.dialog_text = "Want you want to paste?\n(press Ctrl + V again)"
		prompt.default_value = ""
		paste_this = prompt.show()

	insert_text_at_caret(paste_this, caret_index)
