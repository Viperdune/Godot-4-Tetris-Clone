extends Control

@onready var cellContainer = $CellContainer
@onready var pauseMenu = $PauseMenu
@onready var cellScene = preload("res://scenes/cell.tscn")

var pieceShapes = {
	O = [[0, 0], [0, 1], [-1, 0], [-1, 1], false],
	I = [[0, 0], [1, 0], [2, 0], [-1, 0], true],
	S = [[0, 0], [-1, 0], [0, 1], [1, 1], true],
	Z = [[0, 0], [1, 0], [0, 1], [-1, 1], true],
	T = [[0, 0], [0, -1], [1, 0], [-1, 0], true],
	L = [[0, 0], [0, -1], [0, 1], [1, 1], true],
	J = [[0, 0], [0, -1], [0, 1], [-1, 1], true]
}

const HEIGHT = 20
const WIDTH = 10

const CELL_SIZE = 32

const PIECE_STARTING_HEIGHT = 0
const PIECE_STARTING_WIDTH = 5

const FALLING_DELAY = 500
const SPEED_FALL_DELAY = 50

const KEY_DOWN_REPEAT_DELAY = 100

const CELL_COLORS = {
	empty = Color(36.0 / 255.0, 36.0 / 255.0, 46.0 / 255.0),
	pieceColors = {
		O = Color(255.0 / 255.0, 243.0 / 255.0, 85.0 / 255.0),
		I = Color(0.0, 170.0 / 255.0, 236.0 / 255.0),
		S = Color(0.0, 169.0 / 255.0, 80.0 / 255.0),
		Z = Color(236.0 / 255.0, 26.0 / 255.0, 79.0 / 255.0),
		T = Color(155.0 / 255.0, 51.0 / 255.0, 147.0 / 255.0),
		L = Color(229.0 / 255.0, 163.0 / 255.0, 37.0 / 255.0),
		J = Color(0.0, 94.0 / 255.0, 170.0 / 255.0)
	}
}

var cellDictionary = {}
var placedCells = {}

var piecesBag = []
var keysDown = {}

var currentFallingPiece = null
var fallingPieceData = {
	height = 0,
	width = 0,
	rotation = 0,
	canRotate = true
}

func newFallingPiece():
	randomize()
	if piecesBag.size() < 1:
		piecesBag = ["O", "I", "S", "Z", "T", "L", "J"]
	
	var i = randi() % piecesBag.size()
	var piece = piecesBag[i]
	
	piecesBag.remove_at(i)
	fallingPieceData = {
		height = PIECE_STARTING_HEIGHT, 
		width = PIECE_STARTING_WIDTH,
		rotation = 0,
		canRotate = pieceShapes[piece][4]
	}
	
	return piece

func rotatePieceOffset(v : Vector2i, rotation):
	if rotation == 90:
		v = Vector2i(-v.y, v.x)
	elif rotation == 180:
		v = Vector2i(-v.x, -v.y)
	elif rotation == 270:
		v = Vector2i(v.y, -v.x)
	
	return v

func getFallingPieceCells(extraVector : Vector2i = Vector2i.ZERO, rotation = fallingPieceData.rotation):
	var tab = []
	if currentFallingPiece:
		var pieceShapeData = pieceShapes[currentFallingPiece]
		for i in range(4):
			var v = rotatePieceOffset(Vector2i(pieceShapeData[i][0], pieceShapeData[i][1]), rotation)
			
			var x = fallingPieceData.width + v.x + extraVector.x
			var y = fallingPieceData.height + v.y + extraVector.y
			var cell = getCellFromPos(x, y)
			
			if cell != null:
				tab.append([cell, x, y])
		
	return tab

func displayFallingPiece():
	var pieceColor = CELL_COLORS.pieceColors[currentFallingPiece]
	for v in getFallingPieceCells():
		v[0].color = pieceColor

func hideFallingPiece():
	for v in getFallingPieceCells():
		v[0].color = CELL_COLORS.empty

func setCellColor(x : int, y : int, color : Color = CELL_COLORS.empty):
	var cell = getCellFromPos(x, y)
	if cell:
		cell.color = color

func getCellFromPos(x : int, y : int):
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT and cellDictionary.has(x):
		return cellDictionary[x][y]

func generateGrid():
	cellContainer.columns = WIDTH
	for x in range(WIDTH):
		cellDictionary[x] = {}
	
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell = cellScene.instantiate()
			cell.custom_minimum_size = Vector2i(CELL_SIZE, CELL_SIZE)
			cell.color = CELL_COLORS.empty
			
			cellContainer.add_child(cell)
			cellDictionary[x][y] = cell

func requestHorizontalMove(n : int):
	var cells = getFallingPieceCells(Vector2i(n, 0))
	if cells.size() == 4:
		for v in cells:
			if placedCells.has(v[1]) and placedCells[v[1]].has(v[2]):
				return
		
		hideFallingPiece()
		fallingPieceData.width += n
			
		displayFallingPiece()

func canFall():
	var cells = getFallingPieceCells(Vector2i(0, 1))
	if cells.size() == 4:
		for v in cells:
			if placedCells.has(v[1]) and placedCells[v[1]].has(v[2]):
				return false
		
		return true
	else:
		return false

func canRotate(r):
	if fallingPieceData.canRotate:
		var cells = getFallingPieceCells(Vector2i.ZERO, r)
		if cells.size() == 4:
			for v in cells:
				if placedCells.has(v[1]) and placedCells[v[1]].has(v[2]):
					return false
			
			return true
		else:
			return false

func _ready():
	generateGrid()
	placeNewFallingPiece()

func requestRotate():
	var targetRotation = (fallingPieceData.rotation + 90) % 360
	if canRotate(targetRotation):
		hideFallingPiece()
		fallingPieceData.rotation = targetRotation
		
		displayFallingPiece()

func checkForFilledRows():
	while true:
		var filledRow = null
		for i in range(HEIGHT, 0, -1):
			var isFilled = true
			for r in range(0, WIDTH, 1):
				var cell = getCellFromPos(r, i)
				if cell == null or cell.color == CELL_COLORS.empty:
					isFilled = false
					break
			
			if isFilled:
				filledRow = i
				break
		
		if filledRow:
			for y in range(filledRow, 0, -1):
				for x in range(0, WIDTH, 1):
					if not placedCells.has(x): continue
					
					var cell = placedCells[x].get(y)
					if cell:
						var thisCellColor = cell.color
						cell.color = CELL_COLORS.empty
						
						placedCells[x].erase(y)
						if y != filledRow:
							var cellBelow = getCellFromPos(x, y + 1)
							if cellBelow:
								cellBelow.color = thisCellColor
								if not placedCells.has(x):
									placedCells[x] = {}
								
								placedCells[x][y + 1] = cellBelow
		else:
			break

func placeNewFallingPiece():
	currentFallingPiece = newFallingPiece()
	
	var cells = getFallingPieceCells()
	if cells.size() == 4:
		for v in cells:
			if placedCells.has(v[1]) and placedCells[v[1]].has(v[2]):
				clearGame()
				return
	
	displayFallingPiece()

func clearGame():
	currentFallingPiece = null
	hideFallingPiece()
	
	placedCells.clear()
	piecesBag.clear()
	
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell = getCellFromPos(x, y)
			if cell:
				cell.color = CELL_COLORS.empty
	
	placeNewFallingPiece()

var nextFallingTick = FALLING_DELAY
func requestFall():
	if canFall():
		var delay = SPEED_FALL_DELAY if Input.is_action_pressed("speed_fall") else FALLING_DELAY
		nextFallingTick = Time.get_ticks_msec() + delay

		hideFallingPiece()
		fallingPieceData.height += 1

		displayFallingPiece()
	else:
		var currentCells = getFallingPieceCells()
		for v in currentCells:
			if not placedCells.has(v[1]):
				placedCells[v[1]] = {}
			
			placedCells[v[1]][v[2]] = v[0]
		
		checkForFilledRows()
		placeNewFallingPiece()

func _process(_delta):
	# pause menu
	if Input.is_action_just_pressed("pause"):
		pauseMenu.visible = not pauseMenu.visible
	
	if not pauseMenu.visible:
		# falling
		if Time.get_ticks_msec() >= nextFallingTick and not Input.is_action_pressed("speed_fall"):
			requestFall()

		# movement
		var hMove = 0
		for v in [["move_right", KEY_DOWN_REPEAT_DELAY], ["move_left", KEY_DOWN_REPEAT_DELAY], ["speed_fall", SPEED_FALL_DELAY]]:
			if Input.is_action_pressed(v[0]):
				if keysDown.has(v[0]):
					if Time.get_ticks_msec() >= keysDown[v[0]]:
						keysDown[v[0]] = Time.get_ticks_msec() + v[1]
					else:
						return
				else:
					keysDown[v[0]] = Time.get_ticks_msec() + v[1]
				
				if v[0] == "move_right":
					hMove += 1
				elif v[0] == "move_left":
					hMove -= 1
				elif v[0] == "speed_fall":
					requestFall()
		
		if hMove != 0:
			requestHorizontalMove(hMove)
		
		# rotation
		if Input.is_action_just_pressed("rotate"):
			requestRotate()
