extends Node

@export var suelo_scene: PackedScene
@export var camara_3d: Node3D
@export var edificio_scene: PackedScene
var longitud_tramo = 50.0 #lingitud de cada piso
var tramos_activos = [] # array que almacena los tramos de piso
var z_proxima_generacion = 0.0 #el "final" del ultimo piso
var volumen_actual: float = 0.0 
var objetivo_volumen: float = 0.0 # Para suavizar el camb
var color_bosque = Color("8B4513") # Café tierra (SaddleBrown)
var color_ciudad = Color("202020") # Gris casi negro (Asfalto)
var x_conexion: float = 0.0



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if camara_3d == null:
		camara_3d = get_viewport().get_camera_3d()
	for i in range(2):
		crear_tramo()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if camara_3d.position.z < (z_proxima_generacion + 50.0):
		crear_tramo()
	borrar_tramos_viejos()
	# SIMULACIÓN: Presiona Espacio para subir el "volumen" (ir a Ciudad)
	# Suelta para bajar a "silencio" (ir a Bosque)
	if Input.is_action_pressed("ui_accept"): # Barra espaciadora
		objetivo_volumen = 1.0
	else:
		objetivo_volumen = 0.0
	
	# INTERPOLACIÓN (Lerp): Esto es lo que hace la transición SUAVE
	# En lugar de saltar de 0 a 1, va cambiando poco a poco (0.1, 0.2, 0.3...)
	volumen_actual = move_toward(volumen_actual, objetivo_volumen, delta * 0.5)


func crear_tramo():
	var nuevo_suelo = suelo_scene.instantiate()
	nuevo_suelo.position = Vector3(0,0,z_proxima_generacion)
	var color_final = color_bosque.lerp(color_ciudad, volumen_actual)
	
	# 2. Calcular la CURVATURA "NATURAL" (Serpiente)
	# Si estamos en ciudad (volumen alto), el camino tiende a enderezarse hacia 0.
	# Si estamos en bosque (volumen bajo), el camino divaga más.
	
	var desviacion_maxima = 10.0 * (1.0 - volumen_actual) # Mucha curva en bosque, poca en ciudad
	# El nuevo punto final será el anterior + un pequeño cambio aleatorio
	# clamp() evita que la carretera se salga del mapa infinitamente
	var x_siguiente = x_conexion + randf_range(-desviacion_maxima, desviacion_maxima)
	x_siguiente = clamp(x_siguiente, -30, 30) # Límites del mundo
	
	# Si estamos en modo CIUDAD TOTAL, forzamos a que vuelva al centro suavemente
	if volumen_actual > 0.8:
		x_siguiente = move_toward(x_siguiente, 0.0, 5.0)
	
	add_child(nuevo_suelo)
	# 3. ORDENAR AL SUELO QUE SE CONSTRUYA (AQUÍ ESTÁ LA SOLUCIÓN DEL COLOR)
	# Le pasamos: Dónde empezar (conexión), Dónde terminar (siguiente), y el Color
	# IMPORTANTE: Como el suelo está en (0,0,Z), sus coordenadas locales son relativas.
	# Pero como movemos todo el nodo suelo, la "x_conexion" debe ser relativa al centro del nodo.
	# ¡Espera! Para simplificar, usaremos coordenadas LOCALES dentro del tramo.
	# El tramo empieza en x_conexion y termina en x_siguiente.
	
	nuevo_suelo.configurar(x_conexion, x_siguiente, color_final)
	
	# Actualizamos la conexión para el PRÓXIMO tramo (El fin de este es el inicio del otro)
	x_conexion = x_siguiente
	
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
