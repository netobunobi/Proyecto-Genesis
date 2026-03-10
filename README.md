# 🏙️ Génesis: Arquitectura Procedural Acústica

## Descripción del Proyecto
Génesis es un sistema generativo desarrollado en Godot 4 que traduce señales de audio en estructuras arquitectónicas tridimensionales en tiempo real. El programa actúa como un "arquitecto digital", interpretando las propiedades espectrales del sonido para dictar las reglas de crecimiento, densidad y proporciones geométricas de una ciudad procedural infinita.

## Tecnologías Utilizadas
* **Motor Gráfico:** Godot Engine 4.x (Forward+ Renderer)
* **Lenguaje:** GDScript
* **Renderizado:** Instanciación de mallas (MeshInstance3D) con colores de vértice (Vertex Colors) e iluminación volumétrica global.

---

## 🧮 Implementación Matemática y Algorítmica

El núcleo de este proyecto prescinde de animaciones predefinidas. Toda la transformación geométrica se calcula en tiempo de ejecución (frame a frame) aplicando los siguientes principios matemáticos al motor de físicas y renderizado.

### 1. Análisis Espectral (Transformada Rápida de Fourier - FFT)
**¿Dónde se usa?** En la captura del micrófono o pista de audio a través del `AudioEffectSpectrumAnalyzer` de Godot.
**¿Cómo funciona?** El bus de audio captura una onda compleja en el dominio del tiempo. El algoritmo FFT transforma esta onda al dominio de la frecuencia, permitiendo aislar bandas específicas (graves, medios, agudos) y extraer su magnitud (energía).

En el código, estas magnitudes se normalizan (de $0.0$ a $1.0$) y se inyectan en los transformadores de los modelos 3D:
* **Frecuencias Bajas (Ej. 20Hz - 250Hz):** Su magnitud se mapea directamente a la escala horizontal de las mallas base (ejes X y Z). Un sonido grave expande la huella del edificio, simulando bases industriales o búnkeres.
* **Frecuencias Altas (Ej. 4000Hz+):** Su magnitud determina la agudeza estructural (eje Y). Picos agudos disparan la creación de antenas o la verticalidad extrema de los módulos superiores.

### 2. Generación Gramatical (Sistemas de Lindenmayer / Sistemas-L)
**¿Dónde se usa?** En el script principal que controla la instanciación de los "Módulos" (bloques de edificios) sobre la cuadrícula (Grid) del mundo.
**¿Cómo funciona?**
Se utiliza un enfoque estocástico basado en gramáticas formales para determinar qué se construye. Definimos un alfabeto de piezas (Nodos 3D: `PlantaBaja`, `PisoMedio`, `Techo`) y reglas de producción que se evalúan en cada iteración espacial.

La regla de crecimiento $R$ depende de la variable de amplitud de audio $A$ y un factor de probabilidad $P$:
* **Axioma Inicial:** `Lote_Vacio`
* **Regla 1 (Silencio relativo):** Si $A < 0.2$, entonces `Lote_Vacio` $\rightarrow$ `Parque`.
* **Regla 2 (Ruido medio):** Si $0.2 \le A < 0.6$, entonces `Lote_Vacio` $\rightarrow$ `PlantaBaja` + `Techo`.
* **Regla 3 (Recursividad por volumen alto):** Si $A \ge 0.6$, la producción se vuelve recursiva. `PisoMedio` genera otro `PisoMedio` encima de sí mismo $n$ veces, donde $n$ es proporcional a la integral de la amplitud en un delta de tiempo. Esto resulta en la creación espontánea de rascacielos.

### 3. Interpolación Lineal Constante (LERP)
**¿Dónde se usa?** Dentro de la función `_process(delta)` en los scripts que controlan la escala (`scale.y`) y el color (cambio de emisión LED) de los edificios.
**¿Cómo funciona?**
Las señales de audio son inherentemente ruidosas y presentan picos discretos. Si mapeamos la amplitud directamente a la escala de un edificio, el modelo 3D "parpadearía" violentamente entre fotogramas. 

Para lograr la transición orgánica característica de Génesis, se aplica interpolación lineal. Se calcula la posición geométrica o tamaño actual $V_{actual}$ y se aproxima al tamaño objetivo dictado por el audio $V_{objetivo}$, avanzando una fracción $t$ (basada en el `delta` de tiempo del motor para independizarlo de los FPS):

$$V(t) = V_{actual} + t(V_{objetivo} - V_{actual})$$

Este cálculo diferencial permite que los edificios crezcan con un "ataque" rápido frente a un grito, pero se encojan con un "decaimiento" suave, simulando elasticidad física.

### 4. Coordenadas Espaciales y Relleno de Matriz (Grid Placement)
**¿Dónde se usa?** En la función que calcula dónde instanciar cada nuevo edificio en el mundo 3D para que no colisionen entre sí.
**¿Cómo funciona?**
El mundo se trata como una matriz bidimensional plana (ejes X, Z). La posición de cada nuevo módulo se calcula iterando sobre índices $i$ y $j$, y multiplicándolos por un factor de separación predefinido (offset). 

$$Posición(X, Z) = (i \times \text{offset}_x, j \times \text{offset}_z)$$

Esto asegura una distribución ortogonal perfecta (como las calles de una ciudad moderna), sobre la cual los algoritmos acústicos aplican sus deformaciones verticales.
