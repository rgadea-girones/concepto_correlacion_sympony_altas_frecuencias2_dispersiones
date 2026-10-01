# Experimento 2 ADCs con INA - Versión 3 con Symphony (Calibración por Resistencia Pura / Opción 2)
-O5
-sv
+define+EXPERIMENTO_CONTACTO_150K+ALTAS_FRECUENCIAS+DISPERSION_CONTACTOS+EXPERIMENTO_K_EXTREMOS+USE_VAMS_MIXED
-top tb_correlacion_portable_python_to_fpga_configurable
+incdir+../src/
-l qrun_experimento_k_extremos_to_fpga_ina_configurable_v3_symphony.log
 -batch
-do "run -all; quit -f"

../src/FFT_mariposa.c
../src/dpi_guardar_datos_detalle_tiempos.c
../src/dpi_pkg_tiempos.sv

../src/electrical_pkg.sv
../src/bioz_block_portable_to_fpga_ina_v3.sv
../src/rp_adc_model_nettype.sv
../src/rp_dac_model_nettype.sv
../src/top_bioimpedancia_circuito_medida_portable_mixed_v3.sv

../src/Fixed2Float.v
../src/Float2Fixed.v
../src/NormalCases.v
../src/Overflow.v
../src/SpecialCases.v
../src/FixedShifter.v
../src/FixedShiftCalc.v
../src/Divisor_Alg_ali2.sv
../src/arctan8b.sv 
../src/arctan8better2.sv
../src/arctan8best.sv
../src/DDS_rafa_red_cuarto.sv
../src/fixed_pkg.vhd
../src/memoria_dual_port.sv
../src/memoria_single_port_vhdl_2008_arctan.vhd
../src/nuevo_radicador_rapido2.sv
../src/premodulo_generico_best.sv
../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p_mejorado_quiza_final.sv
../src/tb_correlacion_ina_2adcs_configurable_to_fpga_v3.sv
