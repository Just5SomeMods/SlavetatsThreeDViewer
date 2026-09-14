class_name tatsSettings extends Tree

var rT : TreeItem
var saveRow : TreeItem
@onready var cameraOf = $"../../SubViewportContainer/SubViewport/Node3D2/OrbitCamera"
@export var SCROLL_SPEED: float = 10 # Speed when use scroll mouse
@export var ZOOM_SPEED: float = 5 # Speed use when is_zoom_in or is_zoom_out is true
@export var ROTATE_SPEED: float = 10
@export var PAN_SPEED: float = 10

var readInSettings : Dictionary

func _ready() -> void:
	readInSettings.assign(defaultSettings)
	
	if FileAccess.file_exists("user://savedSettings.json"):
		readInSettings.assign(JSON.parse_string( FileAccess.get_file_as_string("user://savedSettings.json") ))
	rT = create_item()
	
	var secondRow := create_item(rT)
	secondRow.set_text(0, "Save Texture size")
	secondRow.set_cell_mode(1, TreeItem.CELL_MODE_RANGE )
	secondRow.set_text(1, "128,256,512,1024,2048,4096")
	secondRow.set_editable(1, true)
	secondRow.set_range(1, readInSettings["Saved Texture Size"])
	saveRow = secondRow
	for cS in readInSettings:
		if cS == "Saved Texture Size": continue
		var cRow := create_item(rT)
		cRow.set_text(0, cS)
		cRow.set_cell_mode(1,TreeItem.CELL_MODE_RANGE)
		cRow.set_range(1, readInSettings[cS])
		cRow.set_editable(1, true)
		cRow.set_range_config(1, 0.1, defaultSettings[cS] * 10, 0.1)
		_on_item_edited_indirect(cRow, cS == readInSettings.keys()[-1])

func _on_item_edited_indirect(trItem : TreeItem, saveNow := true):
	var indexOf := trItem.get_index()
	var getVal := trItem.get_range(1) as float
	match indexOf:
		1: cameraOf.PAN_SPEED = getVal
		2: cameraOf.ROTATE_SPEED = getVal
		3: cameraOf.SCROLL_SPEED = getVal
	readInSettings[readInSettings.keys()[indexOf-1]] = getVal
	if saveNow:
		var outFile = FileAccess.open("user://savedSettings.json",FileAccess.WRITE)
		outFile.store_string(JSON.stringify(readInSettings))


var defaultSettings := {
		"Saved Texture Size": 5,
		"Pan Speed" : 2.0,
		"Rotate Speed" : 1.0,
		"Zoom Speed" : 20.0
	}

func _on_item_edited() -> void:
	var cEdited :TreeItem= get_edited()
	_on_item_edited_indirect(cEdited)
