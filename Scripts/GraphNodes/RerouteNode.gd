@icon("res://Assets/Icons/NodesIcons/ToolConnect.svg")
class_name RerouteNode
extends MonologueGraphNode

func _get_node_type() -> StringName:
	return &"NodeReroute"

func _ready():
	title = node_type

func _to_dict() -> Dictionary:
	var next_id_node = get_parent().get_all_connections_from_slot(name, 0)
	
	return {
		"$type": node_type,
		"ID": id,
		"NextID": next_id_node[0].id if next_id_node else -1,
		"EditorPosition": {
			"x": position_offset.x,
			"y": position_offset.y
		}
	}

func _from_dict(dict: Dictionary):
	id = dict.get("ID")
	position_offset.x = dict.EditorPosition.get("x")
	position_offset.y = dict.EditorPosition.get("y")
