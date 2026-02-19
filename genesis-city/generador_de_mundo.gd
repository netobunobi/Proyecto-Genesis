extends Node

@export var suelo_scene: PackedScene
@export var camara_3d: Node3D

@export_group("Escenas")
@export var escena_arbol: PackedScene
@export var escena_edificio: PackedScene
@export var escena_farol: PackedScene

@export_group("Corrección Manual de Altura")
@export var offset_casas: float = -1.0      # <--- JUEGA CON ESTO SI FLOTAN
@export var offset_edificios: float = -5.0  # <--- JUEGA CON ESTO SI FLOTAN

var longitud_tramo = 50.0 
var tramos_activos = [] 
var z_proxima_generacion = 0.0 
var volumen_actual: float = 0.0 
var objetivo_volumen: float = 0.0 

# Colores del entorno
var color_bosque = Color("5c4033") 
var color_ciudad = Color("1a1a1a") 
var color_piso_bosque = Color("2d4c1e") 
var color_piso_ciudad = Color("444444") 

var x_conexion: float = 0.0

func _ready() -> void:
	if camara_3d == null: camara_3d = get_viewport().get_camera_3d()
	for i in range(2): crear_tramo()

func _process(delta: float) -> void:
	if camara_3d.position.z < (z_proxima_generacion + 50.0): crear_tramo()
	borrar_tramos_viejos()
	
	if Input.is_action_pressed("ui_accept"): objetivo_volumen = 1.0
	else: objetivo_volumen = 0.0
	
	volumen_actual = move_toward(volumen_actual, objetivo_volumen, delta * 0.05)

func crear_tramo():
	var nuevo_suelo = suelo_scene.instantiate()
	nuevo_suelo.position = Vector3(0, 0, z_proxima_generacion)
	
	var color_final = color_bosque.lerp(color_ciudad, volumen_actual)
	var color_piso_final = color_piso_bosque.lerp(color_piso_ciudad, volumen_actual)
	
	var desviacion_maxima = 3.0 * (1.0 - volumen_actual)
	var x_siguiente = x_conexion + randf_range(-desviacion_maxima, desviacion_maxima)
	x_siguiente = clamp(x_siguiente, -4.0, 4.0)
	
	if volumen_actual > 0.8: x_siguiente = move_toward(x_siguiente, 0.0, 5.0)
	
	add_child(nuevo_suelo)
	nuevo_suelo.configurar(x_conexion, x_siguiente, color_final, color_piso_final, volumen_actual)
	
	x_conexion = x_siguiente
	tramos_activos.append(nuevo_suelo)
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
		
		# --- BUSCAR EL CUBO VISUAL (MESH) ---
		var mesh_visual = null
		if objeto is MeshInstance3D: mesh_visual = objeto
		elif objeto.get_child_count() > 0:
			for hijo in objeto.get_children():
				if hijo is MeshInstance3D: mesh_visual = hijo; break

		# --- LÓGICA DE FORMA Y COLOR ---
		match datos["tipo"]:
			"ARBOL":
				var escala = randf_range(0.8, 1.5)
				objeto.scale = Vector3.ONE * escala
				
			"CASA":
				# 1. Forma: Baja y gorda
				objeto.scale = Vector3(2.5, 2.0, 2.5)
				
				# 2. Posición: Altura fija + TU AJUSTE MANUAL
				# Si flotan, baja el valor de 'offset_casas' en el inspector
				objeto.position.y = 1.0 + offset_casas
				
				# 3. Color: Aleatorio para parecer pueblo
				if mesh_visual:
					var mat = StandardMaterial3D.new()
					# Colores: Ladrillo, Crema, Blanco
					mat.albedo_color = [Color("b22222"), Color("ffe4c4"), Color("f5f5f5")].pick_random()
					mesh_visual.material_override = mat
				
			"EDIFICIO":
				# 1. Forma: Alta y variada
				var altura = 10.0 + (volumen_actual * 15.0) + randf_range(-2.0, 5.0)
				objeto.scale = Vector3(1.8, altura, 1.8)
				
				# 2. Posición: Mitad de altura + TU AJUSTE MANUAL
				objeto.position.y = offset_edificios
				
				# 3. Color: Moderno (Cristal oscuro, Gris)
				if mesh_visual:
					var mat = StandardMaterial3D.new()
					# Gris oscuro, Azul oscuro, Negro
					mat.albedo_color = [Color("2f4f4f"), Color("1c1c1c"), Color("708090")].pick_random()
					mat.roughness = 0.1 # Brillante como vidrio
					mat.metallic = 0.5
					mesh_visual.material_override = mat
				
			"FAROL":
				objeto.position.y = 0.0 # Siempre al suelo
