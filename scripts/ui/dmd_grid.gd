extends Control
## Draws a dot-matrix grid over the DMD text so it reads like an old plasma display.

const CELL := 4.0

func _draw() -> void:
	var c := Color(0.07, 0.03, 0.01, 0.55)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), c, 1.0)
		x += CELL
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), c, 1.0)
		y += CELL
