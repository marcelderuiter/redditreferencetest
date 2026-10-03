class_name Plan
extends RefCounted
## The reference image read as a level. Every number here was unprojected
## from the reference with scripts/viewmath.py (see docs/reference_study.md);
## rooms are plan rectangles (x0, z0, x1, z1) in metres at a floor height,
## and every link names the two rooms it joins.


static func build() -> Layout:
	var L := Layout.new()

	# North-west keep: guard on a raised platform, braziers on its towers.
	L.room("keep", -18.5, -17.5, -13.0, -14.5, 1.6,
		{walls = {n = 0.9, e = 0.9, s = 0.7, w = 0.9}, towers = {nw = 2.4, ne = 2.4}, tower_fire = true})
	# The rampart stops at the forge's east edge: from there east to the hall
	# the gallery looks down a deep shaft (the reference's upper-left void).
	L.room("rampart", -18.5, -12.0, -13.0, -9.5, 0.0,
		{walls = {n = 0.8, e = 0.8, s = 0.7, w = 0.8}})
	L.room("gallery", -13.0, -18.0, -8.0, -12.0, 0.0,
		{walls = {n = 2.4, e = 1.6, s = 0.8, w = 1.2}, towers = {ne = 3.0}, open_s = true})
	L.room("study", -8.0, -17.0, -2.0, -10.0, 0.0,
		{walls = {n = 2.4, e = 1.0, s = 1.0, w = 1.2}, towers = {nw = 3.0, ne = 2.6}})
	L.room("forge", -18.5, -9.5, -13.0, -3.5, 0.0,
		{walls = {n = 2.6, e = 1.0, s = 0.8, w = 1.4}, towers = {nw = 3.2, sw = 1.8}})
	L.room("hall", -7.5, -10.0, -2.5, 3.0, 0.0,
		{walls = {n = 2.4, e = 0.9, s = 0.7, w = 0.9}})
	L.room("landing", -8.0, 3.0, -2.5, 8.5, 0.0,
		{walls = {n = 0.7, e = 0.8, s = 0.8, w = 0.8}, towers = {sw = 1.6}})
	L.room("throne", -18.5, 1.0, -10.5, 7.0, 0.0,
		{walls = {n = 1.5, e = 0.8, s = 0.8, w = 0.9}, towers = {nw = 2.4, ne = 2.0}})
	L.room("store", 2.0, -16.5, 6.5, -7.5, 0.0,
		{walls = {n = 2.2, e = 1.2, s = 0.8, w = 1.0}, towers = {nw = 2.8}, open_s = true})
	L.room("chapel", 6.5, -13.0, 12.0, -6.5, 1.6,
		{walls = {n = 4.0, e = 1.6, s = 0.7, w = 1.6}, towers = {nw = 4.6, ne = 4.6}})
	# A shaft separates the treasury's balustrade from the east wing.
	L.room("treasury", 12.0, -10.5, 19.5, -4.6, 1.6,
		{walls = {n = 2.4, e = 1.4, s = 0.9, w = 1.2}, towers = {ne = 3.4, se = 2.2}, balustrade = ["s"], open_s = true})
	# The dais sits west of the chapel's axis with a radius of 3.7, as the
	# reference's octagon does: its south-east quarter leaves the right-hand
	# shaft open down to the cellar. (was: the room before that change, which
	# keeps the rest of the level's random detail unchanged; see Build._ghost.)
	L.room("orrery", 5.05, -5.0, 12.45, 2.4, 0.8,
		{round = true, wall_t = 0.4, walls = {n = 0.7, e = 0.7, s = 0.7, w = 0.7}, was = {rect = Rect2(5.25, -5.3, 8.0, 8.0)}})
	L.room("eastwing", 15.0, -2.6, 18.5, 2.5, 0.8,
		{walls = {n = 0.7, e = 1.1, s = 0.8, w = 0.8}, towers = {ne = 2.2}, balustrade = ["s"]})
	# Its north wall stands back from the dais, so the right-hand shaft drops
	# past it as in the reference.
	L.room("cellar", 5.5, 5.0, 17.5, 12.0, 0.0,
		{walls = {n = 0.5, e = 1.2, s = 0.8, w = 1.0}, towers = {nw = 2.0, ne = 2.2, se = 1.8, sw = 1.6}, was = {rect = Rect2(5.5, 4.0, 12.0, 8.0), walls = {n = 0.6}}})
	L.room("lift", -1.5, 3.5, 2.0, 7.5, 0.0,
		{wall_t = 0.15, support = "links", theme = "iron", walls = {n = 0.5, e = 0.5, s = 0.5, w = 0.5}})
	L.room("lowdock", 0.5, 8.0, 3.5, 10.5, -1.2,
		{wall_t = 0.15, support = "posts", theme = "wood", walls = {n = 0.9, e = 0.9, s = 0.9, w = 0.9}})

	L.link("stairs", "keep", "rampart", {width = 2.6, at = -16.0})
	L.link("door", "rampart", "forge", {width = 1.2, at = -16.55})
	L.link("door", "gallery", "study")
	L.link("door", "study", "hall", {at = -5.0})
	L.link("bridge", "study", "store", {at = -15.0})
	L.link("bridge", "forge", "hall", {at = -4.9})
	L.link("door", "hall", "landing", {width = 3.0, at = -5.0})
	L.link("walk", "throne", "landing", {width = 1.6, at = 4.6})
	L.link("bridge", "hall", "orrery", {width = 1.8})
	L.link("girder", "hall", "store", {width = 1.2, at = -8.75})
	L.link("stairs", "chapel", "orrery", {width = 2.0, at = 8.75, was = {at = 9.25}})
	L.link("door", "chapel", "treasury")
	L.link("bridge", "orrery", "eastwing", {at = -1.3})
	L.link("stairs", "orrery", "cellar", {width = 2.0, at = 8.75, was = {at = 9.25}})
	L.link("stairs", "eastwing", "cellar", {width = 1.4})
	L.link("girder", "landing", "lift", {width = 1.4, at = 6.3})
	L.link("girder", "lift", "cellar", {width = 1.4, at = 6.3})
	L.link("stairs", "cellar", "lowdock", {width = 1.4, at = 9.25})

	L.spawn_room = "landing"
	L.spawn_at = Vector2(0.4, 0.45)

	# Keep
	L.prop("statue_knight", "keep", 0.45, 0.25, {weapon = "spear", rot = 10.0})
	L.prop("candles", "keep", 0.9, 0.2)
	# Rampart
	L.prop("candles", "rampart", 0.05, 0.15)
	L.prop("barrel", "rampart", 0.88, 0.3)
	# Gallery
	L.prop("armor_stand", "gallery", 0.2, 0.12)
	L.prop("bench", "gallery", 0.55, 0.1)
	L.prop("candle_stand", "gallery", 0.9, 0.2)
	L.feature("window", "gallery", "n", 0.3)
	L.feature("window", "gallery", "n", 0.7, {lit = true})
	L.feature("banner", "gallery", "n", 0.5)
	# Study
	L.prop("desk", "study", 0.5, 0.45)
	L.prop("statue_seated", "study", 0.5, 0.17)
	L.prop("shelf", "study", 0.5, 0.06)
	L.prop("candle_stand", "study", 0.93, 0.55)
	L.prop("candle_stand", "study", 0.93, 0.85)
	L.prop("candle_stand", "study", 0.08, 0.55)
	L.prop("rug", "study", 0.5, 0.78, {size = Vector2(2.4, 1.6)})
	L.feature("arch", "study", "n", 0.5)
	L.feature("door_arch", "study", "s", 0.5)
	L.feature("banner", "study", "n", 0.15)
	L.feature("banner", "study", "n", 0.85)
	L.prop("chest", "study", 0.15, 0.85)
	# Forge
	L.prop("fireplace", "forge", 0.75, 0.07)
	L.prop("table", "forge", 0.6, 0.32, {rot = 0.0, items = "tools"})
	L.prop("table", "forge", 0.3, 0.78, {rot = 90.0, items = "mugs"})
	L.prop("barrel", "forge", 0.08, 0.55)
	L.prop("barrel", "forge", 0.1, 0.66)
	L.prop("crates", "forge", 0.12, 0.3)
	L.prop("candles", "forge", 0.9, 0.55)
	L.prop("anvil", "forge", 0.85, 0.3)
	L.prop("sacks", "forge", 0.55, 0.9)
	L.feature("sconce", "forge", "w", 0.4)
	# Hall
	L.prop("runner", "hall", 0.45, 0.6, {size = Vector2(1.7, 9.0)})
	L.prop("statue_knight", "hall", 0.62, 0.52, {weapon = "sword"})
	L.prop("armor_stand", "hall", 0.9, 0.2)
	for v in [0.12, 0.6, 0.78, 0.9]:
		L.prop("candle_stand", "hall", 0.06, v)
	for v in [0.3, 0.55, 0.82]:
		L.prop("candle_stand", "hall", 0.94, v)
	L.feature("door_arch", "hall", "n", 0.5)
	L.feature("banner", "hall", "n", 0.15)
	L.feature("banner", "hall", "n", 0.85)
	L.feature("sconce", "hall", "w", 0.45)
	L.feature("sconce", "hall", "e", 0.25)
	# Landing (the player stands where the reference has a knight)
	L.prop("candle_stand", "landing", 0.06, 0.6)
	L.prop("candle_stand", "landing", 0.92, 0.33)
	L.prop("candles", "landing", 0.08, 0.9)
	# Throne room
	L.prop("statue_big", "throne", 0.4, 0.32)
	L.prop("candles", "throne", 0.2, 0.42)
	L.prop("candles", "throne", 0.6, 0.42)
	L.prop("urn", "throne", 0.06, 0.62)
	L.prop("rubble", "throne", 0.88, 0.22)
	L.prop("rubble", "throne", 0.75, 0.85)
	L.feature("arch", "throne", "n", 0.2)
	L.feature("arch", "throne", "n", 0.45)
	L.feature("banner", "throne", "n", 0.75)
	L.prop("sacks", "throne", 0.1, 0.88)
	# Store
	L.prop("barrel", "store", 0.1, 0.42)
	L.prop("barrel", "store", 0.1, 0.52)
	L.prop("barrel", "store", 0.27, 0.47)
	L.prop("crates", "store", 0.18, 0.66)
	L.prop("statue_knight", "store", 0.62, 0.5, {weapon = "axe"})
	L.prop("chest", "store", 0.75, 0.12)
	L.prop("candles", "store", 0.85, 0.8)
	L.prop("shelf", "store", 0.6, 0.05)
	L.prop("sacks", "store", 0.5, 0.8)
	L.feature("sconce", "store", "e", 0.6)
	# Chapel
	L.prop("statue_big", "chapel", 0.5, 0.1, {robed = true})
	L.prop("altar", "chapel", 0.5, 0.3)
	L.prop("statue_knight", "chapel", 0.5, 0.5, {weapon = "sword", kneel = true})
	L.prop("runner", "chapel", 0.39, 0.8, {size = Vector2(1.4, 2.4)})
	# Four stands in a small room: dim pools, so the statue niche stays the
	# focus instead of one white-gold bloom.
	L.prop("candle_stand", "chapel", 0.1, 0.35, {light = 0.6})
	L.prop("candle_stand", "chapel", 0.9, 0.35, {light = 0.6})
	L.prop("candle_stand", "chapel", 0.06, 0.95, {light = 0.6})
	L.prop("candle_stand", "chapel", 0.88, 0.95, {light = 0.6})
	L.feature("alcove", "chapel", "n", 0.5)
	L.feature("banner", "chapel", "w", 0.4)
	L.feature("banner", "chapel", "e", 0.4)
	L.feature("window", "chapel", "n", 0.18, {lit = true})
	L.feature("window", "chapel", "n", 0.82, {lit = true})
	# Treasury
	L.prop("gold", "treasury", 0.3, 0.55)
	L.prop("gold", "treasury", 0.55, 0.7)
	L.prop("gold", "treasury", 0.75, 0.4)
	L.prop("chest", "treasury", 0.55, 0.12)
	L.prop("chest", "treasury", 0.85, 0.15, {rot = -20.0})
	L.prop("statue_knight", "treasury", 0.2, 0.3, {weapon = "sword"})
	L.prop("statue_knight", "treasury", 0.62, 0.38, {weapon = "axe"})
	L.prop("candles", "treasury", 0.95, 0.6)
	L.prop("candles", "treasury", 0.1, 0.9)
	L.prop("coins", "treasury", 0.5, 0.55, {size = Vector2(5.0, 4.5)})
	L.prop("gold", "treasury", 0.88, 0.75)
	L.prop("chest", "treasury", 0.3, 0.12, {open = true})
	for t in [0.18, 0.4, 0.62, 0.84]:
		L.feature("window", "treasury", "n", t, {lit = true})
	# Orrery
	L.prop("orrery", "orrery", 0.5, 0.5, {size = Vector2(1.6, 1.6)})
	for uv in [Vector2(0.24, 0.24), Vector2(0.76, 0.24), Vector2(0.24, 0.76), Vector2(0.76, 0.76)]:
		L.prop("candle_stand", "orrery", uv.x, uv.y)
	L.prop("statuette", "orrery", 0.24, 0.15)
	L.prop("statuette", "orrery", 0.76, 0.85)
	# East wing
	L.prop("statue_knight", "eastwing", 0.55, 0.45, {weapon = "shield"})
	L.prop("candles", "eastwing", 0.85, 0.15)
	L.prop("candle_stand", "eastwing", 0.92, 0.85)
	# Cellar
	L.prop("crates", "cellar", 0.45, 0.25)
	L.prop("crates", "cellar", 0.6, 0.3)
	L.prop("barrel", "cellar", 0.52, 0.45)
	L.prop("barrel", "cellar", 0.7, 0.42)
	L.prop("barrel", "cellar", 0.64, 0.55)
	L.prop("candle_stand", "cellar", 0.4, 0.22)
	L.prop("candle_stand", "cellar", 0.88, 0.62)
	L.prop("candle_stand", "cellar", 0.25, 0.75)
	L.prop("table", "cellar", 0.36, 0.86, {items = "papers"})
	L.prop("chest", "cellar", 0.9, 0.9)
	L.prop("rug", "cellar", 0.68, 0.78, {size = Vector2(2.4, 2.0)})
	L.prop("statuette", "cellar", 0.12, 0.45)
	L.prop("statue_knight", "cellar", 0.92, 0.25, {weapon = "shield"})
	L.prop("candles", "cellar", 0.96, 0.95)
	L.prop("sacks", "cellar", 0.42, 0.5)
	L.prop("barrel", "cellar", 0.08, 0.36)
	L.prop("barrel", "cellar", 0.15, 0.39)
	L.prop("crates", "cellar", 0.62, 0.1)
	L.prop("shelf", "cellar", 0.2, 0.96, {rot = 180.0})
	L.feature("sconce", "cellar", "n", 0.92)
	L.feature("sconce", "cellar", "e", 0.5)
	# Low dock
	L.prop("barrel", "lowdock", 0.2, 0.3)
	L.prop("crates", "lowdock", 0.2, 0.75)
	return L
