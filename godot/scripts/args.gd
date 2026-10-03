class_name Args
extends RefCounted
## Command-line options after `--`, as passed by tools/match.py:
##   --capture=PATH --lut=off|auto --frames=N --size=WxH --seed=N
##   --vignette=F --cam=yaw,pitch,dist,fov[,fx,fy,fz[,keystone]]
## plus --check (headless layout validation) and --topdown (plan view).

var capture := ""
var lut := "auto"
var frames := 45
var size := Vector2i.ZERO
var seed := 7
var vignette := 0.25
var cam := PackedFloat64Array()
var check := false
var topdown := false


static func parse(list: PackedStringArray = OS.get_cmdline_user_args()) -> Args:
	var a := Args.new()
	for arg in list:
		var key := arg
		var value := ""
		var eq := arg.find("=")
		if eq >= 0:
			key = arg.substr(0, eq)
			value = arg.substr(eq + 1)
		match key:
			"--capture":
				a.capture = value
			"--lut":
				a.lut = value
			"--frames":
				a.frames = maxi(1, value.to_int())
			"--size":
				var wh := value.split("x")
				if wh.size() == 2:
					a.size = Vector2i(wh[0].to_int(), wh[1].to_int())
			"--seed":
				a.seed = value.to_int()
			"--vignette":
				a.vignette = value.to_float()
			"--cam":
				for part in value.split(","):
					a.cam.append(part.to_float())
			"--check":
				a.check = true
			"--topdown":
				a.topdown = true
			_:
				push_warning("unknown argument %s" % arg)
	return a
