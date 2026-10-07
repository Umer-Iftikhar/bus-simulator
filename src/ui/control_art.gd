class_name ControlArt
extends RefCounted
## Drawing routines that give the on-screen controls realistic shapes: a
## leather steering wheel with spokes and an airbag hub, rubber-ribbed pedals,
## chrome-bezel round buttons with icons, arrow-shaped indicator stalks and a
## D/R gear gate. All functions draw onto any CanvasItem.

const LEATHER := Color(0.11, 0.11, 0.12)
const CHROME := Color(0.78, 0.8, 0.83)
const STEEL := Color(0.42, 0.44, 0.47)
const RUBBER := Color(0.1, 0.1, 0.11)
const ICON := Color(0.93, 0.94, 0.95)
const LOW_BEAM := Color(0.25, 0.95, 0.4)
const HIGH_BEAM := Color(0.25, 0.55, 1.0)
const INDICATOR_GREEN := Color(0.2, 1.0, 0.35)


## A steering wheel centred at [param c] with outer radius [param r],
## rotated by [param angle] (radians, clockwise positive).
static func wheel(ci: CanvasItem, c: Vector2, r: float, angle: float) -> void:
	var rim := r - 12.0
	ci.draw_arc(c + Vector2(2, 5), rim, 0.0, TAU, 96, Color(0, 0, 0, 0.35), 24.0, true)
	ci.draw_arc(c, rim, 0.0, TAU, 96, LEATHER, 22.0, true)
	# Thumb grips at ten and two o'clock, slightly thicker and lighter.
	for grip in [-PI * 0.78, -PI * 0.22]:
		var g: float = grip + angle
		ci.draw_arc(c, rim, g - 0.28, g + 0.28, 20, LEATHER.lightened(0.1), 27.0, true)
	# Stitching along the inside of the rim.
	for i in 48:
		var a := TAU * i / 48.0 + angle
		ci.draw_circle(c + Vector2.from_angle(a) * (rim - 8.0), 0.9, Color(0.4, 0.4, 0.42))
	# Soft highlight on the upper-left of the leather.
	ci.draw_arc(c, rim + 6.0, PI * 1.08, PI * 1.55, 30, Color(1, 1, 1, 0.16), 3.0, true)
	# Red centre marker at twelve o'clock.
	var top := -PI / 2.0 + angle
	ci.draw_arc(c, rim, top - 0.07, top + 0.07, 8, Color(0.8, 0.12, 0.1), 23.0, true)
	# Three tapered spokes: left, right and bottom.
	var hub := r * 0.3
	for spoke in [PI, 0.0, PI / 2.0]:
		var dir := Vector2.from_angle(spoke + angle)
		var side := dir.orthogonal()
		var inner := c + dir * hub * 0.8
		var outer := c + dir * (rim - 9.0)
		var poly := PackedVector2Array(
			[inner + side * 15.0, outer + side * 8.0, outer - side * 8.0, inner - side * 15.0]
		)
		ci.draw_colored_polygon(poly, STEEL)
		ci.draw_line(inner + side * 13.0, outer + side * 7.0, CHROME.darkened(0.2), 2.0, true)
	# Airbag hub with a chrome emblem.
	ci.draw_circle(c + Vector2(1, 3), hub, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, hub, Color(0.16, 0.16, 0.18))
	ci.draw_arc(c, hub, 0.0, TAU, 48, Color(0.32, 0.32, 0.35), 3.0, true)
	ci.draw_arc(c, hub * 0.38, 0.0, TAU, 24, CHROME, 3.0, true)
	ci.draw_line(
		c + Vector2.from_angle(top) * hub * 0.25,
		c - Vector2.from_angle(top) * hub * 0.25,
		CHROME,
		2.0,
		true
	)


## A pedal filling [param size]: steel frame, rubber pad with ribs. A pressed
## pedal sinks a little and darkens. [param wide] for the brake pad shape.
static func pedal(
	ci: CanvasItem, size: Vector2, pressed: bool, wide: bool, caption: String
) -> void:
	var sink := 7.0 if pressed else 0.0
	var inset := 6.0
	var taper := size.x * (0.06 if wide else 0.12)
	var top_y := inset + sink
	var bottom_y := size.y - inset - 18.0
	if not pressed:
		var shadow := Rect2(Vector2(inset + 4, top_y + 8), size - Vector2(inset * 2, 26))
		ci.draw_rect(shadow, Color(0, 0, 0, 0.35))
	var frame := PackedVector2Array(
		[
			Vector2(inset + taper, top_y),
			Vector2(size.x - inset - taper, top_y),
			Vector2(size.x - inset, bottom_y),
			Vector2(inset, bottom_y),
		]
	)
	ci.draw_colored_polygon(frame, STEEL.darkened(0.25 if pressed else 0.0))
	var pad := PackedVector2Array(
		[
			frame[0] + Vector2(5, 5),
			frame[1] + Vector2(-5, 5),
			frame[2] + Vector2(-5, -5),
			frame[3] + Vector2(5, -5),
		]
	)
	ci.draw_colored_polygon(pad, RUBBER.darkened(0.3 if pressed else 0.0))
	# Horizontal rubber ribs.
	var rib_gap := 13.0 if wide else 11.0
	var y := top_y + 14.0
	while y < bottom_y - 10.0:
		var t := (y - top_y) / (bottom_y - top_y)
		var half := lerpf(size.x / 2.0 - inset - taper, size.x / 2.0 - inset, t) - 12.0
		var cx := size.x / 2.0
		ci.draw_line(
			Vector2(cx - half, y), Vector2(cx + half, y), Color(0.26, 0.26, 0.28), 4.0, true
		)
		y += rib_gap
	ci.draw_polyline(frame + PackedVector2Array([frame[0]]), CHROME.darkened(0.15), 2.0, true)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	ci.draw_string(
		font,
		Vector2((size.x - text_size.x) / 2.0, size.y - 3.0),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		Color(1, 1, 1, 0.75)
	)


## A round button with a chrome bezel and an icon. [param glow] tints the icon.
static func round_button(
	ci: CanvasItem, size: Vector2, held: bool, glow: Color, icon_name: String
) -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 3.0
	if not held:
		ci.draw_circle(c + Vector2(2, 4), r, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, r, CHROME.darkened(0.35))
	ci.draw_arc(c, r - 2.0, PI * 1.05, PI * 1.95, 24, CHROME.lightened(0.2), 3.0, true)
	var face := Color(0.13, 0.14, 0.16) if not held else Color(0.07, 0.07, 0.08)
	ci.draw_circle(c, r - 6.0, face)
	ci.draw_arc(c, r - 8.0, PI * 1.1, PI * 1.9, 20, Color(1, 1, 1, 0.08), 3.0, true)
	var color := glow if glow.a > 0.0 else ICON
	icon(ci, icon_name, c, (r - 6.0) * 0.55, color)


## Draws a small icon centred at [param c] with half-size [param s].
static func icon(ci: CanvasItem, icon_name: String, c: Vector2, s: float, color: Color) -> void:
	match icon_name:
		"horn":
			var bell := PackedVector2Array(
				[
					c + Vector2(-s, -s * 0.25),
					c + Vector2(-s * 0.2, -s * 0.25),
					c + Vector2(s * 0.8, -s * 0.8),
					c + Vector2(s * 0.8, s * 0.8),
					c + Vector2(-s * 0.2, s * 0.25),
					c + Vector2(-s, s * 0.25),
				]
			)
			ci.draw_colored_polygon(bell, color)
			for i in 2:
				var rr := s * (1.05 + i * 0.3)
				ci.draw_arc(c + Vector2(s * 0.2, 0), rr, -0.6, 0.6, 10, color, 2.0, true)
		"camera":
			ci.draw_rect(Rect2(c - Vector2(s, s * 0.6), Vector2(s * 2.0, s * 1.3)), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.85), Vector2(s * 0.6, s * 0.3)), color)
			ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.45, Color(0.13, 0.14, 0.16))
			ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.28, color)
		"menu":
			for x in [-s * 0.45, s * 0.2]:
				ci.draw_rect(Rect2(c + Vector2(x, -s * 0.75), Vector2(s * 0.3, s * 1.5)), color)
		"light", "light_high":
			# Headlamp: a "D" shape with beam rays (angled down for low beam).
			ci.draw_arc(
				c + Vector2(-s * 0.3, 0), s * 0.6, -PI / 2.0, PI / 2.0, 16, color, 3.0, true
			)
			ci.draw_line(
				c + Vector2(-s * 0.3, -s * 0.6), c + Vector2(-s * 0.3, s * 0.6), color, 3.0, true
			)
			var drop := 0.0 if icon_name == "light_high" else s * 0.35
			for i in 3:
				var y := (i - 1) * s * 0.42
				ci.draw_line(
					c + Vector2(s * 0.45, y), c + Vector2(s * 1.1, y + drop), color, 3.0, true
				)


## An arrow-shaped indicator button pointing [param left] or right.
static func arrow_button(ci: CanvasItem, size: Vector2, held: bool, lit: bool, left: bool) -> void:
	var w := size.x
	var h := size.y
	var head := w * 0.42
	var points := PackedVector2Array(
		[
			Vector2(0, h / 2.0),
			Vector2(head, 2),
			Vector2(head, h * 0.25),
			Vector2(w - 2, h * 0.25),
			Vector2(w - 2, h * 0.75),
			Vector2(head, h * 0.75),
			Vector2(head, h - 2),
		]
	)
	if not left:
		for i in points.size():
			points[i].x = w - points[i].x
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(2, 3))
	if not held:
		ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	var fill := Color(0.12, 0.13, 0.15) if not lit else INDICATOR_GREEN.darkened(0.15)
	ci.draw_colored_polygon(points, fill)
	ci.draw_polyline(points + PackedVector2Array([points[0]]), CHROME.darkened(0.2), 2.5, true)


## The gear selector gate: R at the top, D at the bottom, knob on the selection.
static func gear_gate(ci: CanvasItem, size: Vector2, reverse: bool) -> void:
	var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	ci.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(rect, Color(0.12, 0.13, 0.15))
	ci.draw_rect(rect, CHROME.darkened(0.25), false, 2.0)
	var slot_x := size.x * 0.3
	var slot_top := Vector2(slot_x, rect.position.y + 14)
	ci.draw_line(slot_top, Vector2(slot_x, rect.end.y - 14), Color(0.04, 0.04, 0.05), 6.0)
	var font := ThemeDB.fallback_font
	var r_pos := Vector2(size.x * 0.55, rect.position.y + 28)
	var d_pos := Vector2(size.x * 0.55, rect.end.y - 12)
	var dim := Color(1, 1, 1, 0.35)
	var left := HORIZONTAL_ALIGNMENT_LEFT
	ci.draw_string(font, r_pos, "R", left, -1, 24, Color.WHITE if reverse else dim)
	ci.draw_string(font, d_pos, "D", left, -1, 24, dim if reverse else Color.WHITE)
	var knob_y := rect.position.y + 20 if reverse else rect.end.y - 20
	ci.draw_circle(Vector2(slot_x + 1, knob_y + 2), 11, Color(0, 0, 0, 0.4))
	ci.draw_circle(Vector2(slot_x, knob_y), 11, CHROME.darkened(0.1))
	ci.draw_arc(Vector2(slot_x, knob_y), 8, PI * 1.1, PI * 1.8, 10, Color(1, 1, 1, 0.5), 2.0, true)
