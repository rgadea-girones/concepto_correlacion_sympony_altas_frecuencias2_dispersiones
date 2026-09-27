# Experimento 2 ADCs con INA (Optimizaciones Altas Frecuencias y Sin Autoshunt)
-O5
-sv
+define+EXPERIMENTO_CONTACTO_5K+DISPERSION_CONTACTOS
-top tb_correlacion_portable_python_nettype
+incdir+../src/
-l qrun_experimento_k_extremos_nettype_ina.log
-batch
-do "run -all; quit -f"

../src/FFT_mariposa.c
../src/dpi_guardar_datos_detalle_tiempos.c
../src/dpi_pkg_tiempos.sv

../src/electrical_pkg.sv
../src/bioz_block_portable_nettype_ina.sv
../src/rp_adc_model_nettype.sv
../src/rp_dac_model_nettype.sv
../src/analog_top_4p_portable_nettype.sv
../src/top_bioimpedancia_circuito_medida_portable_nettype_ina.sv

../src/Fixed2Float.v
../src/Float2Fixed.v
../src/NormalCases.v
../src/Overflow.v
../src/SpecialCases.v
../src/FixedShifter.v
../src/FixedShiftCalc.v
../src/Divisor_Alg_ali2.sv
../src/arctan8better2.sv
../src/DDS_rafa_red_cuarto.sv
../src/fixed_pkg.vhd
../src/memoria_dual_port.sv
../src/memoria_single_port_vhdl_2008_arctan.vhd
../src/nuevo_radicador_rapido2.sv
../src/premodulo_generico_best.sv
../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p_mejorado_quiza_final.sv
../src/tb_correlacion_ina_2adcs.sv
