class_name PotentialController
extends RefCounted

static func get_random_potential() -> Potential:
	return Potential.new(
		Util.get_random_int(0, 50),
		Util.get_random_int(0, 50),
		Util.get_random_int(0, 50),
		Util.get_random_int(0, 50),
		Util.get_random_int(0, 50),
		Util.get_random_int(0, 50),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0),
		Util.get_random_float(0.5, 2.0)
	)
