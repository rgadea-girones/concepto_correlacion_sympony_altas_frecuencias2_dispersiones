# Experimento reducido: solo K minima y K maxima en Symphony, con autoshunt desactivado

-O5
-sv
-defineall USE_VAMS_MIXED
-defineall USE_BENCHMARK_METADATA
-defineall EXPERIMENTO_K_EXTREMOS
-defineall EXPERIMENTO_SIN_AUTOSHUNT
-top tb_comparacion_3p_vs_4p_portable_python_nettype
+incdir+../src/
-l qrun_experimento_k_extremos_symphony_sin_autoshunt.log
-batch
-do "run -all; quit -f"

../src/FFT_mariposa.c
../src/dpi_guardar_datos_detalle_tiempos.c
../src/dpi_pkg_tiempos.sv
../src/electrical_pkg.sv

../src/top_bioimpedancia_circuito_medida_portable_mixed.sv
../src/Fixed2Float.v
../src/Float2Fixed.v
../src/NormalCases.v
../src/Overflow.v
../src/SpecialCases.v
../src/FixedShifter.v
../src/FixedShiftCalc.v
../src/Divisor_Alg_ali.sv
../src/arctan8b.sv
../src/DDS_rafa_red_cuarto.sv
../src/fixed_pkg.vhd
../src/memoria_dual_port.sv
../src/memoria_single_port_vhdl_2008_arctan.vhd
../src/nuevo_radicador_rapido2.sv
../src/premodulo_generico_best.sv
../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p_mejorado_quiza.sv
../src/tb_comparacion_correlacion_vs_fft_portable_python_reducido_nettype.sv