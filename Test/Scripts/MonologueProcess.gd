extends Control

class_name MonologueProcess

var dir_path

var root_node_id: String
var node_list: Array
var characters: Array
var variables: Array
var events: Array

var next_id
var fallback_id

var rng = RandomNumberGenerator.new()

signal monologue_node_reached(raw_node: Dictionary)
signal monologue_sentence(sentence: String, speaker: String, speaker_name: String)
signal monologue_new_choice(options: Array[Dictionary])
signal monologue_option_choosed(raw_option: Dictionary)
signal monologue_event_triggered(raw_event: Dictionary)
signal monologue_end(raw_end)
signal monologue_play_audio(path: String, stream)
signal monologue_update_background(path: String, background)
signal monologue_custom_action(raw_action: Dictionary)

func _init():
	print("[INFO] Monologue Process initiated")
	monologue_node_reached.connect(_process_node)
	monologue_end.connect(_default_end_process)

func load_dialogue(dialogue_name, custom_start_point = -1):
	var path = dialogue_name + ".json"
	# no neeed for using "\\" inside godot project
	dir_path = path.split("/")
	dir_path.remove_at(len(dir_path)-1)
	dir_path = "/".join(dir_path)
	assert(FileAccess.file_exists(path), "Can't find dialogs file")
	
	var file = FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())

	assert(data.has("RootNodeID"), "Invalid json file, can't find 'RootNodeID'")
	assert(data.has("ListNodes"), "Invalid json file, can't find 'ListNodes'")

	var db : Dictionary
	var db_file_path : String

	if "DBFile" in data:
		db_file_path = data["DBFile"] as String
		db_file_path = path.get_base_dir().path_join(db_file_path)
		var db_file = FileAccess.open(db_file_path, FileAccess.READ)
		db = JSON.parse_string(db_file.get_as_text())
		assert(db.has("Characters"), "Invalid json file, can't find 'Characters'")
		assert(db.has("Variables"), "Invalid json file, can't find 'Variables'")
	
	else:
		assert(data.has("Characters"), "Invalid json file, can't find 'Characters'")
		assert(data.has("Variables"), "Invalid json file, can't find 'Variables'")
	
	root_node_id = data.get("RootNodeID")
	node_list = data.get("ListNodes")

	if db:
		characters = db["Characters"]
		variables = db["Variables"]
	
	else:
		characters = data.get("Characters")
		variables = data.get("Variables")
	
	events = node_list.filter(func(n): return n.get("$type") == "NodeEvent")
	
	next_id = custom_start_point
	if !custom_start_point:
		next_id = root_node_id
	
	print("[INFO] Dialogue " + path + " loaded")
	
	if db:
		print("[INFO] Dialogue DataBase" + db_file_path + " loaded")

func next():
	# Check for an event
	for event in events:
		var condition = event.get("Condition")
		var variable = get_variable(condition.get("Variable"))
		
		var v_val = variable.get("Value")
		var c_val = condition.get("Value")
		
		if variable == null:
			print("[WARNING] Can't find variable. Skipping")
			next()
			return
			
		var condition_pass: bool = false
		match condition.get("Operator"):
			"==":
				condition_pass = v_val == c_val
			">=":
				condition_pass = v_val >= c_val
			"<=":
				condition_pass = v_val <= c_val
			"!=":
				condition_pass = v_val != c_val

		if condition_pass:
			monologue_event_triggered.emit(event)
			fallback_id = next_id
			next_id = event.get("NextID")
			
			events.erase(event)
	
	if next_id is float and next_id == -1:
		if fallback_id:
			next_id = fallback_id
			fallback_id = null
		else:
			monologue_end.emit(null)
	
	var node = find_node_from_id(next_id)
	
	if node:
		monologue_node_reached.emit(node)
	
func _process_node(node: Dictionary):
	match node.get("$type"):
		"NodeRoot":
			next_id = node.get("NextID")
			next()
			return

		"NodeBridgeIn":
			next_id = node.get("NextID")
			next()
			return

		"NodeBridgeOut":
			next_id = node.get("NextID")
			next()
			return

		"NodeSentence":
			next_id = node.get("NextID")
			
			var processed_sentence = process_conditional_text(node.get("Sentence"))
			var speaker_name := str(node["SpeakerID"])
			for character in characters:
				if int(character["ID"]) == int(node["SpeakerID"]):
					speaker_name = character["DisplaySpeakerName"]
			
			monologue_sentence.emit(
				processed_sentence,
				get_speaker(node["SpeakerID"]),
				speaker_name
			)

		"NodeChoice":
			var options: Array = []
			for option_id in node.get("OptionsID"):
				var option = find_node_from_id(option_id)
				if not option:
					print("[WARNING] Can't find option with id: " + option_id)
					continue

				if option.get("Enable") == false:
					continue
				
				options.append(option)
			
			monologue_new_choice.emit(options)

		"NodeDiceRoll":
			var roll = rng.randi_range(0, 100)
			next_id = node.get("FailID")
			if roll <= node.get("Target"):
				next_id = node.get("PassID")
		
			next()
			return

		"NodeAction":
			next_id = node.get("NextID")
			
			var raw_action = node.get("Action")
			match raw_action.get("$type"):
				"ActionOption":
					var option: Dictionary = find_node_from_id(raw_action.get("OptionID"))
					
					if option == null:
						print("[WARNING] Can't find option. Skipping")
						next()
						return
					
					option["Enable"] = raw_action.get("Value")
				"ActionVariable":
					var variable = get_variable(raw_action.get("Variable"))
					
					if variable == null:
						print("[WARNING] Can't find variable. Skipping")
						next()
						return
					
					match raw_action.get("Operator"):
						"=":
							variable["Value"] = raw_action.get("Value")
						"+":
							variable["Value"] += raw_action.get("Value")
						"-":
							variable["Value"] -= raw_action.get("Value")
						"*":
							variable["Value"] *= raw_action.get("Value")
						"/":
							if raw_action.get("Value") != 0:
								variable["Value"] /= raw_action.get("Value")
							else:
								print("[WARNING] Can't divide by value 0")
						
				"ActionCustom":
					match raw_action.get("CustomType"):
						"PlayAudio":
							var full_path = dir_path + "\\assets\\audios\\" + raw_action.get("Value")
							var sound = null
							if FileAccess.file_exists(full_path):
								var track = SfxLoader.load_track(full_path, raw_action.get("Pitch"), raw_action.get("Volume"))
								track.loop = raw_action.get("Loop")
							
							monologue_play_audio.emit(raw_action.get("Value"), sound)

						"UpdateBackground":
							var bg = Image.new()
							var texture = null
							
							var full_path = dir_path + "\\assets\\backgrounds\\" + raw_action.get("Value")
							if FileAccess.file_exists(full_path):
								var err = bg.load(full_path)
								if err != OK:
									print("[WARNING] Failed to load background (" + raw_action.get("Value") + ")")
								else:
									texture = ImageTexture.create_from_image(bg)
							
							monologue_update_background.emit(raw_action.get("Value"), texture)

						"Other":
							monologue_custom_action.emit(raw_action)

				"ActionTimer":
					var time_to_wait = raw_action.get("Value", 0.0)
					if not is_inside_tree():
						print("[WARNING] MonologueProcess is not inside tree and can't create a timer...")
					else:
						await get_tree().create_timer(time_to_wait).timeout
					
			next()
			return

		"NodeCondition":
			var condition = node.get("Condition")
			var variable = get_variable(condition.get("Variable"))
			
			var if_nid = node.get("IfNextID")
			var else_nid = node.get("ElseNextID")
			var v_val = variable.get("Value")
			var c_val = condition.get("Value")
			next_id = if_nid
			
			if variable == null:
				print("[WARNING] Can't find variable. Skipping")
				next()
				return
			
			match condition.get("Operator"):
				"==":
					next_id = if_nid if v_val == c_val else else_nid
				">=":
					next_id = if_nid if v_val >= c_val else else_nid
				"<=":
					next_id = if_nid if v_val <= c_val else else_nid
				"!=":
					next_id = if_nid if v_val != c_val else else_nid
			
			next()
			return

		"NodeEndPath":
			monologue_end.emit(node)

func find_node_from_id(id):
	if not id is String:
		return null
		
	var nodes = node_list.filter(func(node): return node.get("ID") == id)
	if nodes.size() <= 0:
		return null
	return nodes[0]

func get_speaker(id: int) -> String:
	var speaker = characters.filter(func(c): return c["ID"] == id)
	if speaker.size() <= 0:
		return ""
	return speaker[0]["Reference"]

func get_variable(var_name: String):
	var variable = variables.filter(func(v): return v.get("Name") == var_name)
	
	if variable.size() <= 0:
		return null
	return variable[0]

func process_conditional_text(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("(?<=\\{{)(.*?)(?=\\}})")
	var results = regex.search_all(text)
	if not results:
		return text
	
	for r in results:
		var condition: String = r.get_string()
		var original_condition: String = "{{" + condition + "}}"
		condition = condition.strip_edges(true, true)
		
		var if_position = condition.find("if")
		var then_position = condition.find("then")
		var else_position = condition.find("else")
		
		var var_name = condition.substr(if_position + 3, then_position - (if_position + 3)).strip_edges(true, true)
		var then_name = condition.substr(then_position + 5, else_position - (then_position + 5)).strip_edges(true, true).trim_prefix("\"").trim_suffix("\"")
		var else_name = condition.substr(else_position + 5).strip_edges(true, true).trim_prefix("\"").trim_suffix("\"")
		
		var variable = get_variable(var_name)
		
		if not variable:
			print("[ERROR] Can't find the variable " + var_name)
		
		if variable.get("Type") != "Boolean":
			print("[ERROR] The variable can only be of type Boolean (not " + variable.get("Type") + ")")
			return text
		
		if variable.get("Value") == true:
			text = text.replace(original_condition, then_name)
			continue
		text = text.replace(original_condition, else_name)
		
	return text

func _default_end_process(raw_end):
	if not raw_end:
		return
		
	var next_story = raw_end.get("NextStoryName")
	
	# Search in the same directory if the next story is in here.
	var dir = DirAccess.open(dir_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name == next_story + ".json":
				load_dialogue(dir_path + "/" + next_story)
				return true
			file_name = dir.get_next()
	
	return dir != null


func option_selected(option):
	monologue_option_choosed.emit(option)
	
	if option == null:
		print("[CRITICAL] Can't find option. Unexpected exit.")
		monologue_end.emit(null)
		return
	
	next_id = option.get("NextID")
	
	if option.get("OneShot") == true:
		option["Enable"] = false
	
	next()
