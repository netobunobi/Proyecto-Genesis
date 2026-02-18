extends Node3D

@onready var path = $Path3D
@onready var mesh_instance = $MeshInstance3D

# Eliminamos _ready() porque ahora esperaremos órdenes del jefe

# Esta función la llamará el Generador DESPUÉS de poner el suelo en la escena
func configurar(inicio_x: float, fin_x: float, color: Color):
	# 1. Configurar la Curva (Estilo Serpiente)
	path.curve = path.curve.duplicate()
	var curve = path.curve
	curve.clear_points()
	
	# Punto A: Donde terminó el tramo anterior (Conexión perfecta)
	# La 'manecilla' de salida (Vector3(0, 0, -15)) apunta hacia adelante para suavizar
	curve.add_point(Vector3(inicio_x, 0, 0), Vector3(0,0,0), Vector3(0, 0, -15))
	
	# Punto B: Punto medio para dar "personalidad" a la curva
	# Calculamos la mitad exacta entre inicio y fin, y le agregamos un poquitito de ruido
	var mitad_x = (inicio_x + fin_x) / 2.0
	curve.add_point(Vector3(mitad_x, 0, -25))
	
	# Punto C: Donde termina este tramo (El inicio del siguiente)
	curve.add_point(Vector3(fin_x, 0, -50), Vector3(0, 0, 15), Vector3(0,0,0))
	
	# 2. Construir la Malla Sólida (Tu código que ya funcionaba)
	construir_carretera_solida(color)

func construir_carretera_solida(color_recibido: Color):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var curve = path.curve
	var pasos = 30
	var ancho = 3.0 # Carretera angosta de pueblo
	var largo = curve.get_baked_length()
	
	for i in range(pasos + 1):
		var t = float(i) / pasos
		var dist = t * largo
		
		# Obtener posición y dirección
		var pos = curve.sample_baked(dist)
		
		# Truco para que la dirección no falle al final
		var dir = Vector3.FORWARD
		if i < pasos:
			dir = (curve.sample_baked(dist + 0.1) - pos).normalized()
		else:
			dir = (pos - curve.sample_baked(dist - 0.1)).normalized()
			
		var side = dir.cross(Vector3.UP).normalized()
		
		# Vértices (Levantados 0.1 para no chocar con el suelo)
		st.set_uv(Vector2(0, t * 5)) # *5 para que la textura se repita si pones una
		st.add_vertex(pos + (side * ancho) + Vector3(0, 0.1, 0))
		st.set_uv(Vector2(1, t * 5))
		st.add_vertex(pos - (side * ancho) + Vector3(0, 0.1, 0))
	
	# Índices (Triángulos)
	for i in range(pasos):
		var b = i * 2
		st.add_index(b); st.add_index(b + 1); st.add_index(b + 2)
		st.add_index(b + 1); st.add_index(b + 3); st.add_index(b + 2)
	
	st.generate_normals()
	mesh_instance.mesh = st.commit()
	
	# 3. Aplicar el COLOR y Estilo
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color_recibido
	# roughness 1.0 hace que parezca asfalto seco o tierra, no plástico
	mat.roughness = 1.0 
	mesh_instance.material_override = mat
