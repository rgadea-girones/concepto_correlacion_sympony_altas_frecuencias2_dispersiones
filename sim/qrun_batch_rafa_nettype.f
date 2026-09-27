# -uvm 
  -O5
  -sv 
  # -gui
  # -visualizer
  
  # +livecov
  # -debug
  -voptargs="+acc=none"
  # -qwavedb=+signal+class+transaction+msg=error,pa
 #  -qwavedb=+livesim #genial
 #  -qwavedb=+signal
 # -wlf waves.wlf
  -top tb_correlacion_portable_python_nettype
 # -top top_sim
  +incdir+../src/
 # +UVM_TESTNAME=test_fifo
 # +UVM_VERBOSITY=UVM_MEDIUM 
 # +UVM_RECORD
+define+EXPERIMENTO_K_EXTREMOS+EXPERIMENTO_SIN_AUTOSHUNT+ALTAS_FRECUENCIAS 
  -l qrun.log 
 # -L C:/questasim64_2025.1_2/uvm-1.1d/
 #-sv_root C:/questasim64_2025.1_2/uvm-1.1d/win64 
 # -sv_lib uvm_dpi
 # -sv_lib build/libmi_modelo
#  -cover bst
  -batch
-do "run -all; quit -f" 
#-do run_terminal_4p_versus_3p.do 

# 1. declaraciones c y su empaquetamiento en sv
../src/FFT_mariposa.c
# ../src/dpi_guardar_datos.c
#../src/dpi_guardar_datos_yake.c
../src/dpi_guardar_datos_detalle_tiempos.c
../src/dpi_pkg_tiempos.sv

# 2. declaraciones que necesitan licencias de svrnm

../src/electrical_pkg.sv
#../src/res_model.sv
../src/bioz_block_portable_nettype.sv
## atencion cambio2
# ../src/rp_adc_model_nettype_sin_filtro.sv 
## atencion cambio1
#../src/rp_dac_model_nettype_sin_divresistivo.sv
../src/rp_adc_model_nettype.sv 
../src/rp_dac_model_nettype.sv
../src/analog_top_4p_portable_nettype.sv
#../src/analog_top_3p.sv
../src/top_bioimpedancia_circuito_medida_portable_nettype.sv

# 3. declaraciones para el modulo RTL de correlacion
../src/Fixed2Float.v
../src/Float2Fixed.v
../src/NormalCases.v
../src/Overflow.v
../src/SpecialCases.v
../src/FixedShifter.v
../src/FixedShiftCalc.v
#../src/Divisor_Alg2.sv
#../src/Divisor_Alg_ali.sv
../src/Divisor_Alg_ali2.sv
#../src/arctan2.sv
#../src/arctan4.sv
../src/arctan8.sv
../src/arctan8b.sv 
# ../src/arctan8better.sv
../src/arctan8better2.sv
../src/DDS_rafa_red_cuarto.sv
../src/fixed_pkg.vhd
../src/memoria_dual_port.sv
../src/memoria_single_port_vhdl_2008_arctan.vhd
../src/nuevo_radicador_rapido2.sv
#../src/premodulo_generico_mejor.sv
../src/premodulo_generico_best.sv
#../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown.sv
#../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p.sv
../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p_mejorado_quiza_final.sv
#../src/tb_correlacion_vs_golden_post_inversion2.sv
../src/tb_correlacion_vs_golden_post_inversion2_2.sv
# ../src/tb_correlacion_vs_golden_post_inversion2_3.sv
 ../src/tb_correlacion_vs_calibrado_vs_golden.sv

# 4. circuito analogico portable

#../src/rp_adc_model_portable.sv
#../src/rp_dac_model_portable.sv
#  ../src/bioz_block_portable.sv
# ../src/bioz_block_portable_mejorado.sv
# ../src/bioz_block_portable_best.sv
# ../src/analog_top_4p_portable.sv
# ../src/analog_top_3p_portable.sv
#../src/top_bioimpedancia_circuito_medida_portable.sv

#../src/rp_adc_model_portable.sv
#../src/rp_dac_model_portable.sv
#../src/bioz_block_portable_atun.sv 
#../src/analog_top_4p_portable_atun.sv
#../src/analog_top_3p_portable_atun.sv
#../src/top_bioimpedancia_circuito_medida_portable_atun.sv
# ../src/tb_comparacion_3p_vs_4p_portable_python.sv

# ../src/rp_adc_model_portable.sv
# ../src/rp_dac_model_portable.sv
# ../src/bioz_block_portable_atun_yake.sv 
#../src/analog_top_4p_portable_atun_yake.sv
##../src/analog_top_3p_portable_atun_yake.sv
## ../src/top_bioimpedancia_circuito_medida_portable_atun_yake.sv
#../src/top_bioimpedancia_circuito_medida_portable_atun_yake_reducido.sv
# ../src/tb_comparacion_correlacion_vs_fft_portable_python_cristina.sv
#../src/tb_comparacion_correlacion_vs_fft_portable_python_cristina_reducido.sv




