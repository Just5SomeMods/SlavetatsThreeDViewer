extends Node

var nwThing : CompressedTexture2D
var SLAVETATSFOLDERPATH : String

var currentOverlays : Dictionary
var completeDict : Dictionary
var imgSizeMax := 4096

@export var isInDebug : bool = false

@onready var mTree : Tree = $Control/HSplitContainer/TabContainer/Tats/Tats
var mTreeRoot : TreeItem
@onready var mNode3D : Node3D = $Control/HSplitContainer/SubViewportContainer/SubViewport/Node3D
@onready var mMesh : MeshInstance3D = $Control/HSplitContainer/SubViewportContainer/SubViewport/Node3D/MeshInstance3D

@onready var orbCam : OrbitCamera = $Control/HSplitContainer/SubViewportContainer/SubViewport/Node3D2/OrbitCamera
var onlyActive : bool = false:
	set(val):
		onlyActive = val
		if onlyNonOverlap && onlyActive: onlyNonOverlap = false
		if onlyActive: $Control/HBoxContainer/Main/ShowOnlyActive.text = "Show all"
		else: $Control/HBoxContainer/Main/ShowOnlyActive.text = "Show only active"
		
var onlyNonOverlap : bool = false:
	set(val):
		onlyNonOverlap = val
		if onlyActive && onlyNonOverlap: onlyActive = false
		if onlyNonOverlap: $Control/HBoxContainer/Overlap/NonOverlap.text = "Show all"
		else: $Control/HBoxContainer/Overlap/NonOverlap.text = "Show only non-overlap"

var indiciesAndPaths = []
var cAmount : int = 0:
	set(val):
		cAmount = val
		if cAmount == 0:
			cTime = Time.get_ticks_msec()

var cTime : float
var maxAmount : int = 0
var pickedTats : Dictionary[String, Dictionary]

var sectionsDict : Dictionary[String, Array]

var overLaps : Dictionary[String, Array]
var nmToTreeItem : Dictionary[String, TreeItem]
var allRects : Array[PackedVector2Array]
var nmedRects : Dictionary[String, Array]

var overlayBlockedBy : Dictionary[String, String]
var overlayFilterThread : Thread
var randomTatsThread : Thread
var terminateRTats
var terminateOverlayThread : bool = false
var readInStuff : Dictionary[String, Array]
var polIn : Dictionary[String, Array]
@onready var setTree : tatsSettings = $Control/HSplitContainer/TabContainer/Settings

var tatsCheckedAgainst : Dictionary[String, Dictionary]

func readInAllTats():
	for fl in DirAccess.get_files_at(SLAVETATSFOLDERPATH):
		if not fl.ends_with(".json"): continue
		if "yps" in fl: continue
		var inDict : Array = JSON.parse_string(FileAccess.get_file_as_string(SLAVETATSFOLDERPATH + fl))
		inDict = inDict.filter( func(e): return (e.get("area", "").to_lower() == "body") && FileAccess.file_exists(SLAVETATSFOLDERPATH + e["texture"]) )
		
		for subI in inDict:
			var sect = subI.get("section", "")
			if "yps" in sect: continue
			var cSection = sectionsDict.get_or_add(sect.to_lower(), []) as Array
			cSection.append(subI)
	
	for sect in sectionsDict.keys():
		
		var vals = sectionsDict[sect]
		var cIndex = [sect, []]
		indiciesAndPaths.append(cIndex)
		var cSub := mTree.create_item(mTreeRoot)
		cSub.set_text(0, sect)
		cSub.set_expand_right(0, true)
		var subDict = completeDict.get_or_add(sect, {})
		for dic:Dictionary in vals:
			var cSubSub := mTree.create_item(cSub)
			cSubSub.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			cSubSub.set_editable(0, true)
			var identifier = dic["section"].to_lower() + ";" + dic["name"]
			if subDict.has(identifier) or nmToTreeItem.has(identifier):
				continue
			cSubSub.set_text(0, dic["name"])
			subDict[identifier] = dic
			nmToTreeItem[ identifier] = cSubSub
			dic["pthOf"] = SLAVETATSFOLDERPATH + dic["texture"]
			dic["name"] = identifier
			cIndex[1].append([identifier, SLAVETATSFOLDERPATH + dic["texture"]])
			maxAmount += 1
		cSub.set_collapsed_recursive(true)
			
		
			
	

func loadImagesIn(btn:Button):
	
	cAmount = 0
	for i in range(len(indiciesAndPaths)):
		var cIndex = indiciesAndPaths[i]
		for j in range(len(cIndex[1])):
			var outerDict = completeDict[cIndex[0]]
			var innerDict = cIndex[1][j]
			var nmOf = outerDict[innerDict[0]]
			var pthOf = innerDict[1]
			var getLoad = load(pthOf)
			if getLoad:
				var nwImage :Image= getLoad.get_image()
				nwImage.decompress()
				if nwImage.get_size()[0] != imgSizeMax:
					nwImage.resize( imgSizeMax, imgSizeMax )
				var lowerRes = nwImage.duplicate()
				var nwBitMap = BitMap.new()
				nwBitMap.create_from_image_alpha(lowerRes, 0.1)
				var polys = nwBitMap.opaque_to_polygons(Rect2(Vector2(), nwBitMap.get_size()), 2)
				polIn[nmOf["name"]] = polys
				mTreeRoot.get_child(i).get_child(j).set_editable(0,true)
			cAmount += 1
		
	var outFile = FileAccess.open("user://rects.json",FileAccess.WRITE)
	
	
	outFile.store_var(polIn)
	readInStuff.assign(polIn)
	btn.disabled = false

func readInBody(firstUse:= true):
	var fmBody :Image
	if OS.get_name() == "Linux" && isInDebug:
		fmBody = load("./tats/femalebody_1.dds").get_image()
	else:
		fmBody = load("../Textures/Actors/Character/female/femalebody_1.dds").get_image()
	
	fmBody.decompress()
	if firstUse:
		imgSizeMax = fmBody.get_size()[0]
	else:
		fmBody.resize(imgSizeMax,imgSizeMax)
	currentOverlays["BASETEXTUREOFMAIN"] = fmBody

func _ready() -> void:
	if OS.get_name() == "Linux" && isInDebug:
		SLAVETATSFOLDERPATH = "/Nutzerdaten/Games/skyrim/drive_c/Modding/MO2/mods/Alpia Slavetats Pack/Textures/Actors/Character/slavetats/"
	else:
		SLAVETATSFOLDERPATH = "../Textures/Actors/Character/SlaveTats/"
	$Control/HSplitContainer/SubViewportContainer2/SubViewport.world_3d = $Control/HSplitContainer/SubViewportContainer/SubViewport.find_world_3d()
	
	mTree.set_column_title(0, "loaded/Max")
	mTree.set_column_title_alignment(0,HORIZONTAL_ALIGNMENT_LEFT)
	if FileAccess.file_exists("user://rects.json"):
		var inArr = FileAccess.open("user://rects.json",FileAccess.READ).get_var()
		if inArr:
			readInStuff.assign(inArr)
	mTreeRoot = mTree.create_item()
	mTreeRoot.set_text(0, "Hold SHIFT while uncollapsing this to uncollapse all children.")
	readInBody()
	renderNew()
	readInAllTats()
	
	
var timeIntern : float = 0.0
var fromFile = false


func _on_node_3d_done_here() -> void:
	pass # Replace with function body.

var isRenderingNew = false

var rdThread := Thread.new()

func renderThread():
	var getImage := Image.create_empty(imgSizeMax,imgSizeMax,false,Image.FORMAT_RGBA8)
	
	for nwImage in currentOverlays.values():
		if isRenderingNew: break
		getImage.blend_rect(nwImage, Rect2i(0,0,imgSizeMax,imgSizeMax), Vector2i(0,0))
	if !isRenderingNew:
		var nwImage = getImage# Image.create_from_data(imgSizeMax,imgSizeMax,false,Image.FORMAT_RGBA8,getImage.save_png_to_buffer())	
		var nxtThing = ImageTexture.create_from_image(nwImage)
			
		var mat:= mMesh.get_active_material(1) as StandardMaterial3D
		mat.albedo_texture = nxtThing

func renderNew(isLast : bool = false):
	if rdThread.is_started():
		if rdThread.is_alive():
			if !isLast:
				return
		rdThread.wait_to_finish()
		rdThread = Thread.new()
	rdThread.start(renderThread)
		



func _on_tree_item_edited() -> void:
	
	var cEdit : TreeItem = mTree.get_edited()
	_on_tree_item_edited_indirect(cEdit)
	visStart = true

func _on_tree_item_edited_indirect(cEdit: TreeItem, renderNow:bool = true) -> void:
	if onlyNonOverlap && overlayFilterThread && overlayFilterThread.is_started():
		if overlayFilterThread.is_alive():
			terminateOverlayThread = true
		overlayFilterThread.wait_to_finish()
		overlayFilterThread = Thread.new()
	cEdit.get_parent().call_deferred("set_collapsed_recursive" ,false)
	var parName = cEdit.get_parent().get_text(0)
	var nameOf = parName + ";" + cEdit.get_text(0)
	if nameOf in currentOverlays:
		currentOverlays.erase(nameOf)
		pickedTats.erase(nameOf)
	else:
		var nmOf = completeDict[parName][nameOf]
		pickedTats[nameOf] = nmOf
		var txtR = nmOf.get("image", null)
		if txtR:
			currentOverlays[nameOf] = txtR
		else:
			var getLoad = load(nmOf["pthOf"])
			if getLoad:
				var nwImage :Image= getLoad.get_image()
				nwImage.decompress()
				if nwImage.get_size()[0] != imgSizeMax:
					nwImage.resize( imgSizeMax, imgSizeMax )
				nmOf["image"] = nwImage
		currentOverlays[nameOf] = completeDict[parName][nameOf]["image"]

	allRects.clear()
	if readInStuff:
		for tat in pickedTats:
			nmedRects[tat] = readInStuff[tat]
			allRects.append_array(readInStuff[tat])
	if onlyNonOverlap && overlayFilterThread:
		overlayFilterThread.start(filterPossible)
	renderNew(renderNow)
	

func _on_reset_view_pressed() -> void:
	
	orbCam._distance = orbCam.DEFAULT_DISTANCE
	orbCam._rotation = orbCam.initialRota
	orbCam.parentOf.position = Vector3(0,90,0)
	$Control/HSplitContainer/SubViewportContainer2/SubViewport/Node3D3.position = Vector3(0,90,0)

var lastCAmount = 0
var visStart = false
func _process(_delta: float) -> void:
	if Engine.get_frames_drawn() % 20 == 0:
		if lastCAmount != cAmount: 
			var nxtTitle = str(cAmount) + "/" + str(maxAmount) + " time elapsed: " + str(int((Time.get_ticks_msec() - cTime) / 1000))
			mTree.set_column_title(0, nxtTitle)
			lastCAmount = cAmount
		if mTree.get_selected() and mTree.get_selected().visible and visStart:
			mTree.scroll_to_item(mTree.get_selected(), true)
			visStart = false
		

func setLeftFalse():
	pass



func _on_export_tats_pressed() -> void:
		
	var outFile = FileAccess.open("res://chosenTats.json",FileAccess.WRITE)	
	outFile.store_string(JSON.stringify(pickedTats.values().map(func(e): return e["name"])))
	_on_export_dds_pressed_indirect("../Interface/Menus/SavedTat.dds")



		

func sum(inp:Array) -> float:
	return inp.reduce( func(accum,c):
		return accum + c, 0 )
	


func _on_show_only_active_pressed() -> void:
	if !onlyActive:
		for it:TreeItem in nmToTreeItem.values():
			it.visible =  it.is_checked(0)
		for ch in mTreeRoot.get_children():
			if ch.get_next_visible(true).get_parent() == mTreeRoot:
				ch.visible = false
	else:
		mTreeRoot.call_recursive("set_visible", true)
	onlyActive = !onlyActive

func _on_add_random_non_overlap_pressed() -> void:
	add_random_tats(1)
	pass # Replace with function body.


func _on_add_random_non_overlap_10_pressed() -> void:
	add_random_tats(10)
	pass # Replace with function body.


func _on_get_random_non_overlap_pressed() -> void:
	_on_remove_all_tats_pressed()
	_on_show_only_active_pressed()
	add_random_tats(99)

func add_random_tats(amount:int = 20):
	$Control/HBoxContainer/Overlap.get_children().map(func(e): e.disabled = true)
	if !onlyActive || onlyNonOverlap: _on_show_only_active_pressed()
	if randomTatsThread && randomTatsThread.is_started():
		
		if randomTatsThread.is_alive():
			terminateRTats = true
		randomTatsThread.wait_to_finish()
	randomTatsThread = Thread.new()
	randomTatsThread.start(get_random_tats.bind($Control/HBoxContainer/Overlap, amount) )

func get_random_tats(bttn:Control, numTats: int = 20) -> void:
	cAmount = 0
	var toUse := polIn
	if len(readInStuff) > len(polIn): toUse = readInStuff
	var getCopy = toUse.keys().duplicate()
	getCopy.shuffle()
	var chosenTats : Array[String]
	var cTatsNames = currentOverlays.keys().slice(1)
	for tat in cTatsNames:
		chosenTats.append(tat)
		
	var nwThread := Thread.new()
	var indexAdded = 0
	for ky in getCopy:
		cAmount += 1
		var cRects := toUse[ky]
		var overLapsAny = checkTatBlockedByApplTats(ky)
		if !overLapsAny:
			allRects.append_array(cRects)
			chosenTats.append(ky)
			var cTreeI = nmToTreeItem[ky]
			cTreeI.call_deferred("set_checked",0, true)
			cTreeI.call_deferred("set_visible", true)
			cTreeI.get_parent().call_deferred("set_visible", true)
			cTreeI.get_parent().call_deferred("set_collapsed_recursive", true)
			_on_tree_item_edited_indirect(cTreeI, false)
			renderNew(false)
			indexAdded += 1
			if indexAdded >= numTats:
				break
	cAmount = maxAmount
	if nwThread.is_started():
		nwThread.wait_to_finish()
	renderNew(true)
	bttn.get_children().map(func(e): e.disabled = false)


func _on_load_all_pressed() -> void:
	$Control/HBoxContainer/Overlap/LoadAll.disabled = true
	var nwThread = Thread.new() ; nwThread.start(loadImagesIn.bind($Control/HBoxContainer/Overlap/LoadAll))


func _on_remove_last_pressed() -> void:
	remove_tats(1)
	pass # Replace with function body.


func _on_remove_last_10_pressed() -> void:
	remove_tats(10)
	pass # Replace with function body.

func remove_tats(amount:int) -> void:
	var gtTats = currentOverlays.keys()
	if amount >= len(gtTats): amount = -1
	
	if amount == -1:
		currentOverlays = {"BASETEXTUREOFMAIN": currentOverlays["BASETEXTUREOFMAIN"]}
		pickedTats.clear()
		mTreeRoot.call_recursive("set_checked", 0,false)
	else:
		var toRemove = gtTats.slice(-1 * amount)
		for tat in toRemove:
			currentOverlays.erase(tat)
			pickedTats.erase(tat)
			nmToTreeItem[tat].set_checked(0, false)	
	if onlyActive && len(currentOverlays) == 1:
		_on_show_only_active_pressed()
	renderNew(true)

func _on_remove_all_tats_pressed() -> void:
	if onlyActive:
		_on_show_only_active_pressed()
	currentOverlays = {"BASETEXTUREOFMAIN": currentOverlays["BASETEXTUREOFMAIN"]}
	pickedTats.clear()
	mTreeRoot.call_recursive("set_checked", 0,false)
	renderNew(true)
	


func _on_export_dds_pressed() -> void:
	var bsePath := "../Textures/Actors/Character/SlaveTats/ST3DViewer/SavedTat_"
	if OS.get_name() == "Linux" && isInDebug: bsePath = "res://SavedTat_"
	var lstFile = bsePath + "9.dds"
	if FileAccess.file_exists(lstFile):
		DirAccess.remove_absolute(lstFile)
		
	for i in range(8,-1,-1):
		var cFile = bsePath + str(i) + ".dds"
		if FileAccess.file_exists(cFile):
			DirAccess.rename_absolute(cFile,bsePath+ str(i+1) + ".dds")
		
	_on_export_dds_pressed_indirect(bsePath + "0.dds")


func _on_export_dds_pressed_indirect(outFile = "../Textures/Actors/Character/SlaveTats/ST3DViewer/SavedTat.dds") -> void:
	mTree.call_deferred("set_process_mode" ,  Node.PROCESS_MODE_DISABLED)
	var saveSize = pow(2, 7 + setTree.saveRow.get_range(1) ) as int
	var getImage := Image.create_empty(saveSize,saveSize,false,Image.FORMAT_RGBA8)
	if saveSize > imgSizeMax:
		for nmOf:Dictionary in pickedTats.values():
			var getLoad = load(nmOf["pthOf"])
			var nwImage :Image= getLoad.get_image()
			nwImage.decompress()
			if nwImage.get_size()[0] != saveSize:
				nwImage.resize( saveSize, saveSize )
			getImage.blend_rect(nwImage, Rect2i(0,0,saveSize,saveSize), Vector2i(0,0))
	else:
		for nwImage in currentOverlays.values().slice(1):
			getImage.blend_rect(nwImage, Rect2i(0,0,imgSizeMax,imgSizeMax), Vector2i(0,0))
	
	getImage.save_dds(outFile)


func trAndParentVisible(trI:TreeItem):
	trI.get_parent().visible = true
	trI.get_parent().set_collapsed_recursive(false)
	trI.visible = true
	if lEdit.text: trI.visible = lEdit.text in trI.get_text(0)

func shuffleTree():
	var allChildren = mTreeRoot.get_children()
	allChildren.shuffle()
	allChildren.map(func(e:TreeItem): e.move_before(mTreeRoot.get_child(0)))

func checkTatBlockedByApplTats(ky:String) -> bool:
	var cRects := readInStuff[ky]
	var overLapsAny : bool
	var getBlockedBy : Dictionary = tatsCheckedAgainst.get_or_add(ky, {"blocked_by":[], "not_blocked_by":[]})
	if nmedRects.keys().any(func(e): return e in getBlockedBy["blocked_by"]):
		overLapsAny = true
	else:
		for applKy in nmedRects:
			if applKy in getBlockedBy["not_blocked_by"]: continue
			var cpRect = nmedRects[applKy]
			overLapsAny = checTatBlockedByOtherTat(cRects, cpRect)
			if overLaps: getBlockedBy["blocked_by"].append(applKy)
			else: getBlockedBy["not_blocked_by"].append(applKy)
			if overLapsAny || terminateOverlayThread: break
				
	return overLapsAny

func checTatBlockedByOtherTat(cRects:Array, cpRect:Array ) -> bool:
	var overLapsAny : bool = false
	for inRect:PackedVector2Array in cRects:
		for iCRect: PackedVector2Array in cpRect:
			if Geometry2D.intersect_polygons(iCRect, inRect):
				overLapsAny = true
				break
	return overLapsAny


func set_vis_if_not_disabled(subI:TreeItem):
	subI.visible = subI.is_selected(0)

@onready var lEdit :LineEdit= $Control/HSplitContainer/TabContainer/Tats/LineEdit

func filterPossible():
	cAmount = 0
	for trI in mTreeRoot.get_children():
		for subI in trI.get_children():
			call_deferred("set_vis_if_not_disabled", subI)
	#mTreeRoot.call_deferred("call_recursive", "set_visible", false)
	mTreeRoot.call_deferred("set_visible", true)
	#call_deferred("shuffleTree")
	for ky in nmedRects:
		call_deferred("trAndParentVisible", nmToTreeItem[ky])
	for ky in readInStuff:
		if terminateOverlayThread: break 
		var overLapsAny = checkTatBlockedByApplTats(ky)
		if ky not in nmToTreeItem: continue
		if !overLapsAny: call_deferred("trAndParentVisible", nmToTreeItem[ky])
		cAmount += 1
	cAmount = maxAmount
	terminateOverlayThread = false
	mTree.call_deferred("scroll_to_item" ,mTree.get_selected())

func _on_non_overlap_pressed() -> void:
	onlyNonOverlap = !onlyNonOverlap
	if onlyNonOverlap:
		if overlayFilterThread && overlayFilterThread.is_alive():
			terminateOverlayThread = true
			overlayFilterThread.wait_to_finish()
		overlayFilterThread = Thread.new()
		overlayFilterThread.start(filterPossible)
	

var overThread := Thread.new()
func _on_all_overlaps_pressed() -> void:
	if overThread.is_started(): overThread.wait_to_finish()
	
	overThread.start(testingStuf)

func testingStuf():
	cAmount = 0
	var allKys = readInStuff.keys()
	var strMatrix = []
	var outText = ",\"" + "\",\"".join(allKys.slice(0,-1)) + "\"\n"

	maxAmount = int((len(readInStuff) * len(readInStuff)) / 2.0)
	for i in range(len(readInStuff) -1, 0, -1 ):
		var ky = allKys[i]
		var nxtLine = []
		strMatrix.append(nxtLine)
		nxtLine.resize((len(readInStuff)))
		nxtLine.fill("")
		nxtLine[0] = "\"" + ky + "\""
		var parRect = readInStuff[ky]
		for j in range(i):
			var jky = allKys[j]
			var cRect = readInStuff[jky]
			var overlapsI : int = checTatBlockedByOtherTat(parRect,cRect) as int
			nxtLine[j+1] = overlapsI
			cAmount += 1
	
	for i in range(len(strMatrix)):
		outText += ",".join(strMatrix[i]) + "\n"
	var outFile = FileAccess.open("user://outText.csv",FileAccess.WRITE)	
	outFile.store_string(outText)
	
			


func _on_settings_item_edited() -> void:
	pass # Replace with function body.


func _on_line_edit_text_changed(new_text: String) -> void:
	for trI in mTreeRoot.get_children():
		for subI in trI.get_children():
			if not new_text: subI.call_deferred("set_visible", true)
			else: subI.call_deferred("set_visible",  new_text in subI.get_text(0))
