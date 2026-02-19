extends Node3D

@onready var path = $Path3D
@onready var mesh_carretera = $MeshInstance3D
@onready var mesh_piso = $Piso

var puntos_para_spawn = [] 

# AHORA PEDIMOS EL FACTOR BIOMA (0.0 = Bosque, 1.0 = Ciudad)
func configurar(inicio_x: float, fin_x: float, color_carretera: Color, color_suelo: Color, factor_bioma: float):
	# 1. Configurar Curva (Igual)
	path.curve = path.curve.duplicate()
	var curve = path.curve
	curve.clear_points()
	
	# Curva más suave en ciudad, más cerrada en bosque
	var longitud_tangente = 15.0 + (factor_bioma * 10.0) 
	
	curve.add_point(Vector3(inicio_x, 0, 0), Vector3(0,0,0), Vector3(0, 0, -longitud_tangente))
	var mitad_x = (inicio_x + fin_x) / 2.0
	curve.add_point(Vector3(mitad_x, 0, -25))
	curve.add_point(Vector3(fin_x, 0, -50), Vector3(0, 0, longitud_tangente), Vector3(0,0,0))
	
	# 2. Material Suelo
	var mat_suelo = StandardMaterial3D.new()
	mat_suelo.albedo_color = color_suelo
	mat_suelo.roughness = 1.0
	mesh_piso.material_override = mat_suelo
	
	# 3. Construir y Calcular Objetos pasando el bioma
	construir_todo_junto(color_carretera, factor_bioma)

# En suelo.gd

func construir_todo_junto(color: Color, bioma: float):
	puntos_para_spawn.clear()
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var curve = path.curve
	var pasos = 30
	var ancho_calle = 3.0 
	var largo = curve.get_baked_length()
	
	# 1. DETERMINAR EL TIPO DE BIOMA (ESTADO SÓLIDO)
	# Convertimos el float (0.0 - 1.0) en un entero (0, 1, 2)
	# 0 = Bosque, 1 = Pueblo, 2 = Ciudad
	var tipo_bioma = 0
	if bioma < 0.35: tipo_bioma = 0   # Bosque
	elif bioma < 0.75: tipo_bioma = 1 # Pueblo
	else: tipo_bioma = 2              # Ciudad
	
	for i in range(pasos + 1):
		# ... (Cálculo de vértices y asfalto SIGUE IGUAL) ...
		var t = float(i) / pasos
		var dist = t * largo
		var pos = curve.sample_baked(dist)
		
		var dir = Vector3.FORWARD
		if i < pasos: dir = (curve.sample_baked(dist + 0.1) - pos).normalized()
		else: dir = (pos - curve.sample_baked(dist - 0.1)).normalized()
		var side = dir.cross(Vector3.UP).normalized()
		
		# DIBUJAR ASFALTO
		st.set_uv(Vector2(0, t * 5)); st.add_vertex(pos + (side * ancho_calle) + Vector3(0, 0.05, 0))
		st.set_uv(Vector2(1, t * 5)); st.add_vertex(pos - (side * ancho_calle) + Vector3(0, 0.05, 0))
		
		# --- LÓGICA DE OBJETOS SEGÚN ESTADO (SIN MEZCLAS) ---
		
		match tipo_bioma:
			0: # === BOSQUE PURO ===
				# Muchos árboles, desordenados, cerca de la calle
				if randf() > 0.5: # 50% de probabilidad por paso
					var distancia = randf_range(5.0, 14.0)
					var lado = 1 if randf() > 0.5 else -1
					puntos_para_spawn.append({
						"posicion": pos + (side * distancia * lado),
						"mirar_hacia": pos,
						"tipo": "ARBOL"
					})

			1: # === PUEBLO (TRANSICIÓN) ===
				# Casas bajitas ordenadas + Algunos árboles de jardín
				
				# Casas (Cada 6 pasos)
				if i % 6 == 0:
					var dist_casa = 16.0
					puntos_para_spawn.append({"posicion": pos + (side * dist_casa), "mirar_hacia": pos, "tipo": "CASA"})
					puntos_para_spawn.append({"posicion": pos - (side * dist_casa), "mirar_hacia": pos, "tipo": "CASA"})
				
				# Árboles decorativos (Menos frecuentes, entre casas)
				if i % 4 == 0 and randf() > 0.3:
					var dist_arbol = 10.0
					var lado = 1 if randf() > 0.5 else -1
					puntos_para_spawn.append({"posicion": pos + (side * dist_arbol * lado), "mirar_hacia": pos, "tipo": "ARBOL"})

			2: # === CIUDAD PURA ===
				# Solo edificios altos y farolas. CERO árboles.
				
				# Rascacielos (Cada 4 pasos)
				if i % 4 == 0:
					var dist_edif = 18.0
					puntos_para_spawn.append({"posicion": pos + (side * dist_edif), "mirar_hacia": pos, "tipo": "EDIFICIO"})
					puntos_para_spawn.append({"posicion": pos - (side * dist_edif), "mirar_hacia": pos, "tipo": "EDIFICIO"})
				
				# Farolas (Cada 8 pasos)
				if i % 8 == 0:
					var dist_farol = ancho_calle + 0.6
					puntos_para_spawn.append({"posicion": pos + (side * dist_farol), "mirar_hacia": pos, "tipo": "FAROL"})
					puntos_para_spawn.append({"posicion": pos - (side * dist_farol), "mirar_hacia": pos, "tipo": "FAROL"})

	# Generar Malla (Igual que siempre)
	for i in range(pasos):
		var b = i * 2
		st.add_index(b); st.add_index(b + 1); st.add_index(b + 2)
		st.add_index(b + 1); st.add_index(b + 3); st.add_index(b + 2)
	st.generate_normals()
	mesh_carretera.mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh_carretera.material_override = mat

func obtener_puntos_spawn():
	return puntos_para_spawn
