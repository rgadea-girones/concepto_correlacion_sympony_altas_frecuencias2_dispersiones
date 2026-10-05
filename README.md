# Prueba de Concepto: Correlación Limpia Symphony (Nettype vs Symphony Deluxe)

Este directorio contiene el entorno de simulación y los scripts de análisis de datos para comparar el rendimiento y la precisión de la simulación de un sistema de bioimpedancia utilizando dos enfoques diferentes:
1. **Simulación rápida con Nettype (RNM):** Utilizando el motor digital puro de Questa.
2. **Simulación analógica/mixta con Symphony (opción Deluxe):** Usando el solver analógico AFS.

## Tareas (Tasks) de Simulación Principales

El flujo de trabajo se basa en las tareas de VS Code definidas en el workspace (o ejecutables mediante scripts equivalentes):

- **Simulate batch rafa nettype:** Lanza la simulación completa del sistema utilizando modelos Nettype (rápida, puramente basada en eventos digitales).
- **Simulate batch rafa symphony deluxe:** Lanza la simulación completa en modo co-simulación utilizando Symphony Deluxe, integrando modelos Verilog-AMS reales y el kernel analógico.

## Experimentos y Mediciones

El objetivo principal es realizar mediciones completas con ambos bancos de pruebas para contrastarlas entre sí.

Un experimento particularmente interesante cubierto en este entorno es el impacto del circuito de **Autoshunt**:
- **Simulaciones sin Autoshunt:** Muestran oscilaciones y errores significativos a bajas frecuencias.
- **Simulaciones con Autoshunt:** Corrigen estos errores, estabilizando la respuesta en las bajas frecuencias.

Estos experimentos (con y sin autoshunt) se ejecutaron tanto en Nettype como en Symphony, demostrando no solo la necesidad del autoshunt, sino también la gran correlación que mantiene Nettype respecto al modelo real (Symphony/Golden) una vez gestionadas estas dependencias dinámicas.

## Análisis de Datos (Scripts de Python en `/sim`)

Dentro de la carpeta `sim/` encontrarás la estructura organizada del experimento y los scripts en Python:

### Estructura del Directorio de Resultados
Para facilitar la revisión por pares, el alojamiento en repositorios y la organización del material publicado, los resultados se han estructurado en las siguientes carpetas:
- `/sim/datos_simulacion/`: Contiene todos los datos crudos originales extraídos directamente de las simulaciones completas (Nettype y Symphony) en formato `.csv`.
- `/sim/resultados_graficas/`: Engloba todas las figuras `.png` (escalas lineales y logarítmicas, diagramas de fase/magnitud) listas para anexar al manuscrito de la revisión.
- `/sim/tablas_comparativas/`: Comprende las métricas detalladas en estadísticos `.csv` (MAE, RMSE, porcentaje de error por década y puntos máximos de error) junto con tablas condensadas en `.md` para rápida lectura de resultados consolidados (con y sin autoshunt).

### Scripts de Visualización
- `comparar_nettype_vs_symphony_golden.py` / `comparar_nettype_vs_symphony_golden_relativo.py`: Evalúan las simulaciones completas frente a sus respectivas versiones Golden, generando las salidas encontradas en `resultados_graficas/` y `tablas_comparativas/`.
- `comparar_autoshunt_reducido_sujeto0.py` / `comparar_autoshunt_reducido_sujeto0_logy.py`: Generan las métricas dedicadas para comprobar específicamente la mejora de precisión que aporta el circuito **Autoshunt**, prestando especial atención a las bajas frecuencias.

### Entorno Virtual

Se recomienda usar el entorno virtual creado (`sim/.venv_articulo_plots`) para ejecutar los scripts de visualización, ya que cuenta con dependencias clave como `pandas`, `numpy` y `matplotlib`.
### Zenodo
[![DOI](https://zenodo.org/badge/1390574957.svg)](https://doi.org/10.5281/zenodo.23155325)
