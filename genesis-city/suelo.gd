extends Node3D

@onready var path = $Path3D
@onready var mesh_instance = $MeshInstance3D

func _ready():
	randomize()
	generar_curva_aleatoria()
	construir_carretera_solida()

func generar_curva_aleatoria():
	var curve = path.curve
	curve.clear_points()
	# Inicio: Vector de salida RECTO para que pegue con el anterior
	curve.add_point(Vector3(0, 0, 0), Vector3(0,0,0), Vector3(0, 0, -10))
	
	# Medio: El serpenteo
	var desvio = randf_range(-7.0, 7.0)
	curve.add_point(Vector3(desvio, 0, -25))
	
	# Final: Vector de entrada RECTO para que pegue con el siguiente
	curve.add_point(Vector3(0, 0, -50), Vector3(0, 0, 10), Vector3(0,0,0))

func construir_carretera_solida():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var curve = path.curve
	var pasos = 30 # Aumentado para más suavidad
	var ancho = 5.0
	var largo_total = curve.get_baked_length()
	
	for i in range(pasos + 1):
		var t = float(i) / pasos
		var dist = t * largo_total
		var pos = curve.sample_baked(dist)
		
		# Cálculo de dirección seguro (evita el error del final del tramo)
		var dir = curve.sample_baked(dist + 0.1) - pos
		if i == pasos: # Si es el último punto, usamos la dirección hacia atrás
			dir = pos - curve.sample_baked(dist - 0.1)
		
		var forward = dir.normalized()
		var side = forward.cross(Vector3.UP).normalized()
		
		# Forzamos que en el inicio y final el ancho sea puramente horizontal (X)
		if i == 0 or i == pasos:
			side = Vector3(1, 0, 0)

		# Vértices con altura fija (0.1) para evitar el suelo café
		st.add_vertex(pos + (side * ancho) + Vector3(0, 0.1, 0))
		st.add_vertex(pos - (side * ancho) + Vector3(0, 0.1, 0))
	
	for i in range(pasos):
		var b = i * 2
		st.add_index(b); st.add_index(b + 1); st.add_index(b + 2)
		st.add_index(b + 1); st.add_index(b + 3); st.add_index(b + 2)
	
	st.generate_normals()
	mesh_instance.mesh = st.commit()
	
	# Material sólido para ver que no haya cortes
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.867, 1.0, 0.102, 1.0) # Negro asfalto
	mesh_instance.material_override = mat	
	
func _process(delta: float) -> void:
	pass
