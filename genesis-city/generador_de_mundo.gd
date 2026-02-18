extends Node

@export var suelo_scene: PackedScene
@export var camara_3d: Node3D
@export var edificio_scene: PackedScene
var longitud_tramo = 50.0 #lingitud de cada piso
var tramos_activos = [] # array que almacena los tramos de piso
var z_proxima_generacion = 0.0 #el "final" del ultimo piso



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if camara_3d == null:
		camara_3d = get_viewport().get_camera_3d()
	for i in range(5):
		crear_tramo()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if camara_3d.position.z < (z_proxima_generacion + 50.0):
		crear_tramo()
	borrar_tramos_viejos()


func crear_tramo():
	var nuevo_suelo = suelo_scene.instantiate()
	nuevo_suelo.position = Vector3(0,0,z_proxima_generacion)
	add_child(nuevo_suelo)
	tramos_activos.append(nuevo_suelo)
	spawnear_edificos(nuevo_suelo)
	z_proxima_generacion -= longitud_tramo
	
	
func borrar_tramos_viejos():
	if tramos_activos.size() > 0:
		var tramo_mas_viejo = tramos_activos[0]
		if camara_3d.position.z < (tramo_mas_viejo.position.z - longitud_tramo -20.0):
			tramo_mas_viejo.queue_free() 
			tramos_activos.pop_front()
			
			
func spawnear_edificos(tramo_actual):
	var contenedor_puntos = tramo_actual.get_node_or_null("PuntosDeSpawn")	
	if contenedor_puntos:
		var hijos = contenedor_puntos.get_children()
		for punto in hijos:
			if edificio_scene == null:
				return
			var edificio = edificio_scene.instantiate()
			tramo_actual.add_child(edificio)
			edificio.global_position = punto.global_position
			var escala_y = randf_range(2.0, 10.0)
			edificio.scale.y = escala_y
			edificio.position.y += escala_y / 2.0
