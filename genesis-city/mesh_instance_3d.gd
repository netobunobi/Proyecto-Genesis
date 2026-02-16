extends MeshInstance3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	rotate_y(1.0*delta)	
	scale.y = 1.0 + (sin(Time.get_ticks_msec()*0.005)*0.5)
	pass
