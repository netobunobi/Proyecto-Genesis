extends Node

@export var suelo_scene: PackedScene
@export var camara_3d: Node3D

@export_group("Escenas")
@export var escena_arbol: PackedScene
@export var escena_edificio: PackedScene
@export var escena_farol: PackedScene

@export_group("Sensibilidad del Micrófono")
@export var ruido_minimo_db: float = -45.0 
@export var ruido_maximo_db: float = -30.0 

@export_group("Corrección Manual de Altura")
@export var offset_casas: float = -1.0
@export var offset_edificios: float = 0.0

var longitud_tramo = 50.0 
var tramos_activos = [] 
var z_proxima_generacion = 0.0 

var capture_effect: AudioEffectCapture 
var volumen_graficador: float = 0.0 
var volumen_actual: float = 0.0

var barra_volumen: ProgressBar
var label_db: Label

var color_bosque = Color("#2a1b14") 
var color_ciudad = Color("#14161a")
var color_piso_bosque = Color("#154222") # Verde pino rico
var color_piso_ciudad = Color("#282c33") # Gris azulado urbano
var x_conexion: float = 0.0
var tiempo_curva: float = 0.0

func _ready() -> void:
	if camara_3d == null: camara_3d = get_viewport().get_camera_3d()
	
	var indice_bus_mic = AudioServer.get_bus_index("Microfono")
	capture_effect = AudioServer.get_bus_effect(indice_bus_mic, 0) as AudioEffectCapture
	
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
	
	for i in range(4): crear_tramo()

func _process(delta: float) -> void:
	# 1. LEER LA ONDA FÍSICA DIRECTAMENTE
	var max_amplitud: float = 0.0
	
	if capture_effect != null:
		var frames_disponibles = capture_effect.get_frames_available()
		if frames_disponibles > 0:
			var buffer_audio = capture_effect.get_buffer(frames_disponibles)
			for frame in buffer_audio:
				var amplitud_actual = abs(frame.x) 
				if amplitud_actual > max_amplitud:
					max_amplitud = amplitud_actual

	# 2. CONVERTIR LA VIBRACIÓN A DECIBELES
	var volumen_db = linear_to_db(max(max_amplitud, 0.0001))
	
	# 3. MATEMÁTICAS DEL BIOMA (Valores fijos y estables)
	var lectura_bruta = clampf((volumen_db - ruido_minimo_db) / (ruido_maximo_db - ruido_minimo_db), 0.0, 1.0)
	
	if lectura_bruta > volumen_graficador:
		volumen_graficador = lectura_bruta 
	else:
		volumen_graficador = move_toward(volumen_graficador, 0.0, delta * 0.15)
	
	# --- INTERFAZ ---
	if barra_volumen != null:
		barra_volumen.value = volumen_graficador * 100.0
	if label_db != null:
		label_db.text = "Micro: " + str(snapped(volumen_db, 0.1)) + " dB"
	
	if camara_3d.position.z < (z_proxima_generacion + 70.0):
		crear_tramo()
		
	borrar_tramos_viejos()

# ----------------------------------------------------------------------
func crear_tramo():
	var bioma_envio = volumen_graficador
	longitud_tramo = 50.0
	
	var nuevo_suelo = suelo_scene.instantiate()
	nuevo_suelo.position = Vector3(0, 0, z_proxima_generacion)
	
	var color_final = color_bosque.lerp(color_ciudad, bioma_envio)
	var color_piso_final = color_piso_bosque.lerp(color_piso_ciudad, bioma_envio)
	
	# --- NUEVA MATEMÁTICA DEL CAMINO SERPENTEANTE ---
	tiempo_curva += 0.4 # Velocidad de la curva (0.4 hace que la curva sea larga y suave)
	
	# La amplitud máxima es 3.5 metros hacia los lados (no se despega mucho del centro).
	# Al multiplicarlo por (1.0 - bioma_envio), la curva se aplana a 0 en la ciudad.
	var amplitud_curva = 3.5 * (1.0 - bioma_envio) 
	var x_siguiente = sin(tiempo_curva) * amplitud_curva
	# ------------------------------------------------
	
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
	var lista_puntos_original = tramo_actual.obtener_puntos_spawn()
	
	# --- 1. GENERAR ÁRBOLES EXTRA ---
	var puntos_extra = []
	for datos in lista_puntos_original:
		if datos["tipo"] == "ARBOL":
			var cantidad_extra = randi_range(3, 5) 
			for i in range(cantidad_extra):
				var nuevo_dato = datos.duplicate()
				var empuje_x = randf_range(2.0, 10.0)
				if datos["posicion"].x < 0:
					nuevo_dato["posicion"].x -= empuje_x
				else:
					nuevo_dato["posicion"].x += empuje_x
				nuevo_dato["posicion"].z += randf_range(-8.0, 8.0)
				puntos_extra.append(nuevo_dato)
	
	var todos_los_puntos = lista_puntos_original.duplicate()
	todos_los_puntos.append_array(puntos_extra)
	
	# --- 2. FILTRO DE ESPACIO PERSONAL (ANTI-SUPERPOSICIÓN) ---
	var lista_puntos_limpia = []
	
	for dato in todos_los_puntos:
		var posicion_actual = dato["posicion"]
		var hay_choque = false
		
		# Revisamos contra los que ya fueron aprobados
		for punto_aprobado in lista_puntos_limpia:
			var distancia = posicion_actual.distance_to(punto_aprobado["posicion"])
			
			# Distancia segura por defecto (4.5 metros)
			var dist_minima = 4.5
			
			# Si alguno de los dos objetos es un EDIFICIO, necesitan mucho más espacio
			if dato["tipo"] == "EDIFICIO" or punto_aprobado["tipo"] == "EDIFICIO":
				dist_minima = 6.0
			# Los FAROLES son muy delgados, no estorban tanto
			elif dato["tipo"] == "FAROL" or punto_aprobado["tipo"] == "FAROL":
				dist_minima = 1.0
				
			if distancia < dist_minima:
				hay_choque = true
				break # Dejamos de revisar porque ya chocó con algo
				
		# Si no chocó con nadie, lo agregamos a la lista oficial
		if not hay_choque:
			lista_puntos_limpia.append(dato)
			
	# --- 3. CONSTRUIR SOLO LOS OBJETOS APROBADOS ---
	for datos in lista_puntos_limpia:
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
				# --- LIMPIEZA ---
				for hijo in objeto.get_children():
					if hijo is MeshInstance3D: hijo.queue_free()
				objeto.scale = Vector3.ONE
				objeto.position.y = offset_edificios
				
				# --- MATERIALES DE BOSQUE ---
				var mat_tronco = StandardMaterial3D.new()
				mat_tronco.albedo_color = Color("#3e2723") # Café corteza oscuro
				mat_tronco.roughness = 1.0
				
				var mat_hojas = StandardMaterial3D.new()
				# Varios tonos de pino y bosque profundo
				mat_hojas.albedo_color = [Color("#1b5e20"), Color("#2e7d32"), Color("#33691e")].pick_random() 
				mat_hojas.roughness = 0.9
				
				# --- TAMAÑO Y TRONCO ---
				var altura_tronco = randf_range(1.5, 3.0)
				
				var tronco = MeshInstance3D.new()
				tronco.mesh = CylinderMesh.new()
				tronco.mesh.top_radius = 0.15
				tronco.mesh.bottom_radius = 0.25
				tronco.mesh.height = altura_tronco
				tronco.position.y = altura_tronco / 2.0
				tronco.material_override = mat_tronco
				objeto.add_child(tronco)
				
				# --- HOJAS LOW-POLY (Cubos superpuestos) ---
				var num_bloques_hojas = randi_range(2, 4)
				var altura_actual_hojas = altura_tronco - 0.2 # Empezamos un poco abajo de la punta del tronco
				
				for i in range(num_bloques_hojas):
					var hojas = MeshInstance3D.new()
					hojas.mesh = BoxMesh.new()
					
					# Hacemos que la copa sea grande abajo y se haga chica hacia arriba (como un pino)
					var tamaño = randf_range(1.5, 2.5) - (i * 0.4) 
					hojas.mesh.size = Vector3(tamaño, tamaño * 0.8, tamaño)
					
					hojas.position.y = altura_actual_hojas + (tamaño * 0.4)
					
					# Pequeño desfase y rotación aleatoria para que se vea natural y orgánico
					hojas.position.x = randf_range(-0.15, 0.15)
					hojas.position.z = randf_range(-0.15, 0.15)
					hojas.rotation_degrees.y = randf_range(0, 90)
					
					hojas.material_override = mat_hojas
					objeto.add_child(hojas)
					
					# Subimos para colocar el siguiente bloque de hojas
					altura_actual_hojas += tamaño * 0.4
				
			"CASA":
				# --- LIMPIEZA ---
				for hijo in objeto.get_children():
					if hijo is MeshInstance3D: hijo.queue_free()
				objeto.scale = Vector3.ONE
				objeto.position.y = offset_edificios
				
				# --- MATERIALES DE CASA ---
				# Colores pastel o típicos de casas (blanco, beige, azul claro, salmón)
				var mat_pared = StandardMaterial3D.new()
				mat_pared.albedo_color = [Color("#f5f5dc"), Color("#e0f7fa"), Color("#fce4ec"), Color("#fff3e0"), Color("#d7ccc8")].pick_random()
				mat_pared.roughness = 0.9
				
				# Techos (Teja roja, madera oscura o gris asfalto)
				var mat_techo = StandardMaterial3D.new()
				mat_techo.albedo_color = [Color("#8b0000"), Color("#5d4037"), Color("#263238")].pick_random()
				mat_techo.roughness = 0.8
				
				var mat_puerta = StandardMaterial3D.new()
				mat_puerta.albedo_color = Color("#4e342e") # Madera oscura
				
				var mat_luz_on = StandardMaterial3D.new()
				mat_luz_on.albedo_color = Color("#ffeaa7")
				mat_luz_on.emission_enabled = true
				mat_luz_on.emission = Color("#ffd384")
				mat_luz_on.emission_energy_multiplier = 2.0
				
				var mat_luz_off = StandardMaterial3D.new()
				mat_luz_off.albedo_color = Color("#111111")
				
				# --- DIMENSIONES ---
				var ancho = randf_range(3.0, 3.8)
				var prof = randf_range(3.0, 3.8)
				var alto_piso = 1.8
				
				# Reactividad al micrófono, pero con LÍMITE. (Una casa no tiene 20 pisos)
				var pisos = 1 + int(volumen_actual * 4.0) 
				if pisos > 3: pisos = 3 # Máximo 3 pisos aunque grites durísimo
				
				var altura_acumulada = 0.0
				
				# --- CONSTRUCCIÓN POR PISOS ---
				for p in range(pisos):
					var pared = MeshInstance3D.new()
					pared.mesh = BoxMesh.new()
					pared.mesh.size = Vector3(ancho, alto_piso, prof)
					pared.position.y = altura_acumulada + (alto_piso / 2.0)
					pared.material_override = mat_pared
					objeto.add_child(pared)
					
					if p == 0:
						# PLANTA BAJA: Siempre lleva una puerta en el centro
						var puerta = MeshInstance3D.new()
						puerta.mesh = BoxMesh.new()
						puerta.mesh.size = Vector3(1.0, 1.4, 0.2)
						puerta.position = Vector3(0, altura_acumulada + 0.7, prof / 2.0 + 0.05)
						puerta.material_override = mat_puerta
						objeto.add_child(puerta)
					else:
						# PISOS SUPERIORES: Llevan un par de ventanas
						var ventana = MeshInstance3D.new()
						ventana.mesh = BoxMesh.new()
						ventana.mesh.size = Vector3(1.2, 0.8, 0.2)
						ventana.position = Vector3(0, altura_acumulada + (alto_piso / 2.0), prof / 2.0 + 0.05)
						
						# 50% de probabilidad de luz encendida
						if randf() > 0.5: ventana.material_override = mat_luz_on
						else: ventana.material_override = mat_luz_off
						
						objeto.add_child(ventana)
						
					altura_acumulada += alto_piso
				
				# --- EL TECHO TRIANGULAR (A DOS AGUAS) ---
				var techo = MeshInstance3D.new()
				techo.mesh = PrismMesh.new() # ¡Este es el nodo mágico en forma de triángulo!
				techo.mesh.size = Vector3(ancho + 0.4, 1.5, prof + 0.4) # Un poco más ancho que la casa
				techo.position.y = altura_acumulada + 0.75 # Justo arriba del último piso
				techo.material_override = mat_techo
				objeto.add_child(techo)
				
				# --- GIRAR LA CASA HACIA LA CALLE ---
				if objeto.position.x < 0: objeto.rotation_degrees.y = 90
				else: objeto.rotation_degrees.y = -90
			
			"EDIFICIO":
				# --- LIMPIEZA ---
				for hijo in objeto.get_children():
					if hijo is MeshInstance3D: hijo.queue_free()
				objeto.scale = Vector3.ONE
				objeto.position.y = offset_edificios

				# --- 1. MATERIALES (Colores realistas y luces tenues) ---
				var colores_ciudad = [
					Color("#8e8e8e"), # Gris neutro
					Color("#a8a39d"), # Beige grisáceo
					Color("#7c8082"), # Gris acero
					Color("#bda893"), # Arena/Concreto claro
					Color("#8b645a"), # Ladrillo pálido
					Color("#525859")  # Asfalto oscuro
				]
				var mat_pared = StandardMaterial3D.new()
				mat_pared.albedo_color = colores_ciudad.pick_random()
				mat_pared.roughness = 0.9

				# El material del separador blanco que te gustó
				var mat_borde = StandardMaterial3D.new()
				mat_borde.albedo_color = Color("#dcdde1")
				mat_borde.roughness = 1.0

				# Materiales de Ventana (Luz cálida y tenue)
				var mat_luz_on = StandardMaterial3D.new()
				mat_luz_on.albedo_color = Color("#ffeaa7")
				mat_luz_on.emission_enabled = true
				mat_luz_on.emission = Color("#ffd384") # Color cálido
				mat_luz_on.emission_energy_multiplier = 1.2 # Intensidad realista (foco de casa)

				var mat_luz_off = StandardMaterial3D.new()
				mat_luz_off.albedo_color = Color("#111111") # Casi negro
				mat_luz_off.roughness = 0.1 # Un poco de reflejo

				var mat_puerta = StandardMaterial3D.new()
				mat_puerta.albedo_color = [Color("#2c3e50"), Color("#54433a")].pick_random()

				# --- 2. DIMENSIONES Y CÁLCULOS ---
				var ancho = randf_range(3.5, 5.0) 
				var prof = randf_range(3.5, 5.0)
				var alto_piso = 2.2 # Pisos un poco más altos para que quepan bien las ventanas
				
				# La altura depende del volumen del micrófono
				var pisos_extra = int(volumen_actual * 15.0)
				var total_pisos = 3 + pisos_extra + randi_range(0, 2)
				var altura_acumulada = 0.0

				# --- LÓGICA DE PATRÓN CONSTANTE ---
				# Decidimos ANTES de empezar cuántas ventanas tendrá este edificio por piso
				# para que se mantenga igual de abajo hacia arriba.
				var num_ventanas = randi_range(2, 4)
				var espacio_x = ancho / (num_ventanas + 1)
				# Calculamos un ancho de ventana proporcional al espacio disponible
				var ancho_ventana = clamp(espacio_x * 0.7, 0.5, 1.2)

				# --- 3. BUCLE PRINCIPAL DE CONSTRUCCIÓN (Piso por Piso) ---
				for piso in range(total_pisos):
					# A. Pared del piso actual
					var pared = MeshInstance3D.new()
					pared.mesh = BoxMesh.new()
					pared.mesh.size = Vector3(ancho, alto_piso, prof)
					pared.position.y = altura_acumulada + (alto_piso / 2.0)
					pared.material_override = mat_pared
					objeto.add_child(pared)
					
					# B. El Separador/Cornisa blanca (justo encima de la pared)
					var borde = MeshInstance3D.new()
					borde.mesh = BoxMesh.new()
					# Sobresale 0.3 unidades para dar relieve
					borde.mesh.size = Vector3(ancho + 0.3, 0.2, prof + 0.3)
					borde.position.y = altura_acumulada + alto_piso
					borde.material_override = mat_borde
					objeto.add_child(borde)

					# C. Generación de Ventanas para este piso
					for v in range(num_ventanas):
						# Calculamos la posición horizontal exacta basada en el patrón
						var pos_x = -(ancho / 2.0) + (espacio_x * (v + 1))
						
						# Lógica de Puerta: Solo en planta baja (piso 0) y si es la ventana de en medio
						if piso == 0 and v == int(num_ventanas / 2.0):
							var puerta = MeshInstance3D.new()
							puerta.mesh = BoxMesh.new()
							puerta.mesh.size = Vector3(1.2, 1.8, 0.1)
							# Posición: Z positivo (frente), ligeramente salida (+0.05)
							puerta.position = Vector3(pos_x, altura_acumulada + 0.9, prof / 2.0 + 0.05)
							puerta.material_override = mat_puerta
							objeto.add_child(puerta)
						else:
							# Es una ventana normal
							var ventana = MeshInstance3D.new()
							ventana.mesh = BoxMesh.new()
							ventana.mesh.size = Vector3(ancho_ventana, 1.2, 0.1)
							# Posición: Z positivo (frente), ligeramente salida (+0.05)
							ventana.position = Vector3(pos_x, altura_acumulada + (alto_piso / 2.0), prof / 2.0 + 0.05)
							
							# 35% de probabilidad de que la luz esté prendida
							if randf() > 0.65:
								ventana.material_override = mat_luz_on
							else:
								ventana.material_override = mat_luz_off
								
							objeto.add_child(ventana)
							
					# Subimos la altura para el siguiente piso
					altura_acumulada += alto_piso
					
				# --- 4. GIRAR EL EDIFICIO HACIA LA CALLE ---
				if objeto.position.x < 0:
					# Banqueta izquierda: gira a la DERECHA (+90)
					objeto.rotation_degrees.y = 90 
				else:
					# Banqueta derecha: gira a la IZQUIERDA (-90)
					objeto.rotation_degrees.y = -90
						
			"FAROL":
				objeto.scale = Vector3.ONE 
				objeto.position.y = 0.0 
				
				# Si la posición X es menor a 0, está en la banqueta izquierda
				if objeto.position.x < 0:
					# Gira 90 grados a la derecha para ver la calle
					objeto.rotation_degrees.y = -90 
				else:
					# Gira 90 grados a la izquierda para ver la calle
					objeto.rotation_degrees.y = 90
# --- 4. EL TRUCO ANTI POP-IN: ANIMACIÓN DE BROTE ---
		# Guardamos a dónde debe llegar
		var y_final = objeto.position.y
		# Lo hundimos 30 metros bajo la tierra para que nazca desde abajo
		objeto.position.y -= 30.0 
		
		# Creamos una animación fluida
		var tween = get_tree().create_tween()
		# Tarda 1.2 segundos en subir. TRANS_QUAD y EASE_OUT hacen que frene suavemente al llegar arriba.
		tween.tween_property(objeto, "position:y", y_final, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
