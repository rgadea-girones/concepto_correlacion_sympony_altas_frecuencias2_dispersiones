# Simulacion mixta controlada por Questa: SV top + VAMS top + Verilog-A bioz

-O5
-sv
-voptargs="+acc=none"
-vopt.options -vams -end
-defineall USE_VAMS_MIXED
-top tb_comparacion_3p_vs_4p_portable_python_nettype
+incdir+../src/
+incdir+/root/solido_symphony/solidosim/questasim/verilog_src/adms_vlams/
-l qrun_mixed_ams.log
-batch
-do "run -all; quit -f"

# 1. DPI y utilidades C/SV
../src/FFT_mariposa.c
../src/dpi_guardar_datos_detalle.c
../src/dpi_pkg.sv

# 2. Compilacion analogica para Symphony/AFS desde Questa
-filemap
  ../src/bioz_block_portable_va.va
  -vlog.options -vams -vamsfilesuffix=va,vams -end
-endfilemap

-filemap
  ../src/dac_ams_wrapper.vams
  ../src/adc_ams_wrapper.vams
  ../src/analog_top_4p_portable_ams.vams
  ../src/top_bioimpedancia_ams.vams
  -vlog.options -vams -vamsfilesuffix=vams -end
-endfilemap

# 3. Wrapper SV y RTL digital
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