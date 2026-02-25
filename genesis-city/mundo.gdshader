shader_type sky;

// --- CONFIGURACIÓN ---
uniform vec3 color_cielo_arriba : source_color = vec3(0.01, 0.01, 0.03);
uniform vec3 color_horizonte : source_color = vec3(0.02, 0.02, 0.05);

// Estrellas:
uniform float umbral_estrellas : hint_range(0.99, 0.9999) = 0.999; 
// Velocidad mucho más baja por defecto
uniform float velocidad_titileo : hint_range(0.0, 2.0) = 0.2; 

// Luna:
uniform float tamano_luna : hint_range(0.0, 0.1) = 0.03;
uniform vec3 color_luna : source_color = vec3(1.0, 1.0, 0.9);

// POSICIÓN LUNA CORREGIDA A LA FUERZA:
// Z = -1.0 (Bien enfrente). Y = 0.3 (Apenas arribita del horizonte).
// Ahora sí tiene que verse ahí enfrente.
uniform vec3 posicion_luna = vec3(0.0, 0.3, -1.0);


float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void sky() {
    // 1. Fondo
    float col = clamp(EYEDIR.y, 0.0, 1.0);
    vec3 cielo_final = mix(color_horizonte, color_cielo_arriba, col);

    // 2. Estrellas con VIBRACIÓN SUTIL
    vec3 dir_estrellas = normalize(EYEDIR);
    vec2 sky_uv = dir_estrellas.xz / (abs(dir_estrellas.y) + 0.05);
    
    vec2 vibracion = vec2(sin(TIME * velocidad_titileo), cos(TIME * velocidad_titileo * 0.8));
    vec2 uv_animado = sky_uv * 150.0 + (vibracion * 0.0003);
    
    float noise_val = random(uv_animado);
    float estrellas = step(umbral_estrellas, noise_val);
    
    float dist_luna_check = distance(normalize(EYEDIR), normalize(posicion_luna));
    estrellas *= step(tamano_luna * 2.0, dist_luna_check);
    
    // --- LA SOLUCIÓN MÁGICA: MÁSCARA DE HORIZONTE ---
    // smoothstep(0.05, 0.25) significa: A los 5 grados de altura la visibilidad es 0%. 
    // A los 25 grados hacia arriba, la visibilidad ya es 100%.
    float mascara_horizonte = smoothstep(0.05, 0.25, EYEDIR.y);
    estrellas *= mascara_horizonte; // Multiplicamos las estrellas por la máscara
    // ------------------------------------------------
    
    cielo_final += vec3(estrellas * 0.8);

    // 3. La Luna
    float dist_luna = distance(normalize(EYEDIR), normalize(posicion_luna));
    float borde_suave = smoothstep(tamano_luna + 0.01, tamano_luna - 0.005, dist_luna);
    
    // También multiplicamos la luna por la máscara por si la pones muy bajita
    vec3 color_luna_enmascarada = color_luna * mascara_horizonte;
    cielo_final = mix(cielo_final, color_luna_enmascarada, borde_suave * mascara_horizonte);

    COLOR = cielo_final;
}