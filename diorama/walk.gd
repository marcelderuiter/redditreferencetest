class_name Walk
extends RefCounted
## Walkable surfaces. Each shape answers "is this xz point on me, and how high?"

var kind := ""
var a := Vector2.ZERO
var b := Vector2.ZERO
var h0 := 0.0
var h1 := 0.0
var along_x := false
var width := 0.0
var radius := 0.0

static func rect(x0: float, z0: float, x1: float, z1: float, h: float, margin := 0.45) -> Walk:
	var w := Walk.new()
	w.kind = "rect"
	w.a = Vector2(minf(x0, x1) + margin, minf(z0, z1) + margin)
	w.b = Vector2(maxf(x0, x1) - margin, maxf(z0, z1) - margin)
	w.h0 = h
	w.h1 = h
	return w

## Ramp from (x0,z0) side at h0 to (x1,z1) side at h1 along one axis.
static func ramp(x0: float, z0: float, x1: float, z1: float, h0_: float, h1_: float, along_x_: bool) -> Walk:
	var w := Walk.new()
	w.kind = "ramp"
	w.a = Vector2(x0, z0)
	w.b = Vector2(x1, z1)
	w.h0 = h0_
	w.h1 = h1_
	w.along_x = along_x_
	return w

static func seg(p0: Vector2, p1: Vector2, width_: float, h0_: float, h1_: float) -> Walk:
	var w := Walk.new()
	w.kind = "seg"
	w.a = p0
	w.b = p1
	w.width = width_
	w.h0 = h0_
	w.h1 = h1_
	return w

static func circle(c: Vector2, r: float, h: float) -> Walk:
	var w := Walk.new()
	w.kind = "circle"
	w.a = c
	w.radius = r
	w.h0 = h
	return w

## Height at p, or NAN when p is not on this shape.
func height(p: Vector2) -> float:
	match kind:
		"rect":
			if p.x >= a.x and p.x <= b.x and p.y >= a.y and p.y <= b.y:
				return h0
		"ramp":
			# ramps overlap the floors they join along their run
			var ext := Vector2(0.6, 0.0) if along_x else Vector2(0.0, 0.6)
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - ext
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + ext
			if p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y:
				var t := (p.x - a.x) / (b.x - a.x) if along_x else (p.y - a.y) / (b.y - a.y)
				return lerpf(h0, h1, clampf(t, 0.0, 1.0))
		"seg":
			var d := b - a
			var t := (p - a).dot(d) / d.length_squared()
			var ext := 0.8 / d.length()  # bridges reach into the rooms they join
			if t >= -ext and t <= 1.0 + ext:
				var off := absf((p - a).dot(Vector2(-d.y, d.x).normalized()))
				if off <= width * 0.5:
					return lerpf(h0, h1, clampf(t, 0.0, 1.0))
		"circle":
			if p.distance_to(a) <= radius:
				return h0
	return NAN

## Best surface height near `current`, or NAN when off every surface.
static func height_at(shapes: Array, p: Vector2, current: float, max_step := 0.6) -> float:
	var best := NAN
	for s in shapes:
		var h: float = s.height(p)
		if is_nan(h) or absf(h - current) > max_step:
			continue
		if is_nan(best) or absf(h - current) < absf(best - current):
			best = h
	return best
