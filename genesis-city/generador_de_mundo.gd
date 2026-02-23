extends Node

@export var suelo_scene: PackedScene
@export var camara_3d: Node3D

# ---> ¡NUEVO! EL GUARDÍAN DEL NODO <---
@export var reproductor_mic: AudioStreamPlayer 

@export_group("Escenas")
@export var escena_arbol: PackedScene
@export var escena_edificio: PackedScene
@export var escena_farol: PackedScene

@export_group("Sensibilidad del Micrófono")
@export var ruido_minimo_db: float = -60.0 
@export var ruido_maximo_db: float = -35.0 

@export_group("Corrección Manual de Altura")
@export var offset_casas: float = -1.0
@export var offset_edificios: float = 0.0

var longitud_tramo = 50.0 
var tramos_activos = [] 
var z_proxima_generacion = 0.0 

var indice_bus_mic: int
var spectrum_analyzer
var volumen_graficador: float = 0.0 
var volumen_actual: float = 0.0

# --- VARIABLES PARA VER EL MICRO EN PANTALLA ---
var barra_volumen: ProgressBar
var label_db: Label

# Colores del entorno
var color_bosque = Color("5c4033") 
var color_ciudad = Color("1a1a1a") 
var color_piso_bosque = Color("2d4c1e") 
var color_piso_ciudad = Color("444444") 

var x_conexion: float = 0.0

func _ready() -> void:
	if camara_3d == null: camara_3d = get_viewport().get_camera_3d()
	
	# Buscamos el nodo de audio
	reproductor_mic = get_node_or_null("../AudioStreamPlayer") 
	
	indice_bus_mic = AudioServer.get_bus_index("Microfono")
	
	# --- INICIALIZACIÓN DE LA INTERFAZ (Para evitar el error 'Nil') ---
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	barra_volumen = ProgressBar.new()
	barra_volumen.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	barra_volumen.custom_minimum_size = Vector2(0, 40)
	canvas.add_child(barra_volumen)
	
	label_db = Label.new()
	label_db.position = Vector2(10, 50)
	label_db.add_theme_font_size_override("font_size", 30)
	canvas.add_child(label_db)
	
	for i in range(2): crear_tramo()

func _process(delta: float) -> void:
	# 1. CAPTURA DE VOLUMEN
	var volumen_db = AudioServer.get_bus_peak_volume_left_db(indice_bus_mic, 0)
	
	# 2. EL SALVAVIDAS (Solo si existe el nodo)
	if reproductor_mic != null:
		if volumen_db < -70.0 and not reproductor_mic.playing:
			reproductor_mic.play()
	
	# 3. CONVERSIÓN A BIOMA
	var lectura_bruta = clampf((volumen_db - ruido_minimo_db) / (ruido_maximo_db - ruido_minimo_db), 0.0, 1.0)
	
	# 4. GRAFICADOR (MEMORIA)
	if lectura_bruta > volumen_graficador:
		volumen_graficador = lectura_bruta 
	else:
		volumen_graficador = move_toward(volumen_graficador, 0.0, delta * 0.15)
	
	# --- ACTUALIZAR INTERFAZ (Ya no dará error Nil porque se crearon arriba) ---
	if barra_volumen != null:
		barra_volumen.value = volumen_graficador * 100.0
	if label_db != null:
		label_db.text = "Señal Real: " + str(snapped(volumen_db, 0.1)) + " dB"
	
	if camara_3d.position.z < (z_proxima_generacion + 60.0):
		crear_tramo()
		
	borrar_tramos_viejos()
	
func crear_tramo():
	var bioma_envio = volumen_graficador
	longitud_tramo = 50.0
	
	var nuevo_suelo = suelo_scene.instantiate()
	nuevo_suelo.position = Vector3(0, 0, z_proxima_generacion)
	
	var color_final = color_bosque.lerp(color_ciudad, bioma_envio)
	var color_piso_final = color_piso_bosque.lerp(color_piso_ciudad, bioma_envio)
	
	var desviacion_maxima = 3.0 * (1.0 - bioma_envio)
	var x_siguiente = x_conexion + randf_range(-desviacion_maxima, desviacion_maxima)
	x_siguiente = clamp(x_siguiente, -4.0, 4.0)
	
	if bioma_envio > 0.8: 
		x_siguiente = move_toward(x_siguiente, 0.0, 5.0)
	
	add_child(nuevo_suelo)
	nuevo_suelo.configurar(x_conexion, x_siguiente, color_final, color_piso_final, bioma_envio)
	
	x_conexion = x_siguiente
	tramos_activos.append(nuevo_suelo)
	
	volumen_actual = bioma_envio
	spawnear_edificios(nuevo_suelo) 
	
	z_proxima_generacion -= longitud_tramo

func borrar_tramos_viejos():
	if tramos_activos.size() > 0:
		var tramo_mas_viejo = tramos_activos[0]
		if camara_3d.position.z < (tramo_mas_viejo.position.z - longitud_tramo - 20.0):
			tramo_mas_viejo.queue_free()
			tramos_activos.pop_front()

func spawnear_edificios(tramo_actual):
	var lista_puntos = tramo_actual.obtener_puntos_spawn()
	
	for datos in lista_puntos:
		var escena_a_usar: PackedScene = null
		
		match datos["tipo"]:
			"ARBOL": escena_a_usar = escena_arbol
			"CASA": escena_a_usar = escena_edificio 
			"EDIFICIO": escena_a_usar = escena_edificio
			"FAROL": escena_a_usar = escena_farol
		
		if escena_a_usar == null: continue
		
		var objeto = escena_a_usar.instantiate()
		tramo_actual.add_child(objeto)
		objeto.position = datos["posicion"]
		
		if objeto.position.distance_to(datos["mirar_hacia"]) > 0.1:
			objeto.look_at(datos["mirar_hacia"], Vector3.UP)
		
		var mesh_visual = null
		if objeto is MeshInstance3D: mesh_visual = objeto
		elif objeto.get_child_count() > 0:
			for hijo in objeto.get_children():
				if hijo is MeshInstance3D: mesh_visual = hijo; break

		match datos["tipo"]:
			"ARBOL":
				var escala = randf_range(0.8, 1.5)
				objeto.scale = Vector3.ONE * escala
				
			"CASA":
				var altura_casa = 2.0 + (volumen_actual * 3.0) 
				objeto.scale = Vector3(2.5, altura_casa, 2.5)
				objeto.position.y = offset_casas
				
			"EDIFICIO":
				var altura = 10.0 + (volumen_actual * 15.0) + randf_range(-2.0, 5.0)
				objeto.scale = Vector3(1.8, altura, 1.8)
				objeto.position.y = offset_edificios
				
				if mesh_visual:
					var mat = StandardMaterial3D.new()
					mat.albedo_color = [Color("2f4f4f"), Color("1c1c1c"), Color("708090")].pick_random()
					mat.roughness = 0.1 
					mat.metallic = 0.5
					mesh_visual.material_override = mat
				
			"FAROL":
				objeto.position.y = 0.0
