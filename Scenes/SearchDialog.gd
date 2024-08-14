extends Window

@export var min_size_y := 70
@export var max_size_y := 300

@onready var markup := load("res://Test/Data/markdown_settings.tres")

func _on_cancel_pressed():
	hide()

func _on_visibility_changed():
	size.y = min_size_y
	%NoInteractions.visible = visible
	if not visible:
		%SearchEdit.text = ""
		%ScrollNodesContainer.hide()
		return
	
	%SearchEdit.grab_focus()

func _on_search_pressed():
	search_in_nodes(%SearchEdit.text)

func _on_search_edit_text_submitted(new_text):
	search_in_nodes(new_text)

func add_btn_to_node(node: MonologueGraphNode, value: String):
	var btn := Button.new()
	
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "%s:\n%s" % [
		node.node_type, value
	]
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	btn.pressed.connect(_on_found_pressed.bind(node))
	%NodesContainer.add_child(btn)

func _on_found_pressed(node: MonologueGraphNode):
	hide()
	var graph := get_parent().get_current_graph_edit() as GraphEdit
	graph.set_selected(node)
	graph.scroll_offset = node.position_offset * Vector2(0.5, 1)

func search_in_nodes(thing_to_find: String):
	thing_to_find = thing_to_find.to_lower()
	size.y = max_size_y
	%ScrollNodesContainer.show()
	var nodes = get_parent().get_graph_nodes()
	
	for node: MonologueGraphNode in nodes:
		if node is SentenceNode:
			if thing_to_find in node.sentence.to_lower():
				add_btn_to_node(node, node.sentence)
			continue

		if node is CommentNode:
			if thing_to_find in node.comment.to_lower():
				add_btn_to_node(node, node.comment)
			continue
		
		if node is ChoiceNode:
			for op: OptionReference in node.get_children():
				if thing_to_find in op.sentence.to_lower():
					add_btn_to_node(node, op.sentence)
					break
			continue
