class_name MonologueGraphNode
extends GraphNode

var graph_edit : GraphEdit
var id: String = UUID.v4()
var node_type: String = "NodeUnknown"

func _from_dict(_dict: Dictionary):
	pass

func _to_dict():
	pass

func _update(_panel = null):
	pass

func _common_update(_panel = null):
	size.y = 0
	if _panel: id = _panel.id

func _gui_input(event):
	if !graph_edit: graph_edit = get_parent()
	
	if event is InputEventMouseButton:
		var mouse_ev := event as InputEventMouseButton
		if mouse_ev.button_index != MOUSE_BUTTON_LEFT: return
		if self in graph_edit.selected_nodes:
			if graph_edit.selected_nodes == [self]: return
			for node: GraphNode in graph_edit.selected_nodes:
				node.selected = node == self

func _connect_to_panel(sgnl):
	sgnl.connect(_update)
	sgnl.connect(_common_update)
