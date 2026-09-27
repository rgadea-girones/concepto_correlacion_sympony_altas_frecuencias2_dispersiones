# -uvm 
  -O5
  -sv 
  # -gui
  # -visualizer
  
  # +livecov
  # -debug
  -voptargs="+acc=none"
  # -qwavedb=+signal+class+transaction+msg=error,pa
 # -qwavedb=+livesim #genial
  -top tb_comparacion_3p_vs_4p_portable_python
 # -top top_sim
  +incdir+../src/
 # +UVM_TESTNAME=test_fifo
 # +UVM_VERBOSITY=UVM_MEDIUM 
 # +UVM_RECORD
  -l qrun.log 
 # -L C:/questasim64_2025.1_2/uvm-1.1d/
 #-sv_root C:/questasim64_2025.1_2/uvm-1.1d/win64 
 # -sv_lib uvm_dpi
 # -sv_lib build/libmi_modelo
#  -cover bst
  -batch
-do "run -all; quit -f" 
#-do run_terminal_4p_versus_3p.do
../src/FFT_mariposa.c
../src/dpi_guardar_datos.c

../src/dpi_pkg.sv
../src/electrical_pkg.sv
../src/res_model.sv
../src/bioz_block_nettype.sv
../src/rp_adc_model_nettype.sv
../src/rp_dac_model_nettype.sv
../src/analog_top_4p.sv
../src/analog_top_3p.sv
../src/Fixed2Float.v
../src/Float2Fixed.v
../src/NormalCases.v
../src/Overflow.v
../src/SpecialCases.v
../src/FixedShifter.v
../src/FixedShiftCalc.v

../src/rp_adc_model_portable.sv
../src/rp_dac_model_portable.sv

../src/top_bioimpedancia_circuito_medida.sv
#  ../src/bioz_block_portable.sv
# ../src/bioz_block_portable_mejorado.sv
# ../src/bioz_block_portable_best.sv
# ../src/analog_top_4p_portable.sv
# ../src/analog_top_3p_portable.sv
#../src/top_bioimpedancia_circuito_medida_portable.sv

../src/bioz_block_portable_atun.sv 
../src/analog_top_4p_portable_atun.sv
../src/analog_top_3p_portable_atun.sv
../src/top_bioimpedancia_circuito_medida_portable_atun.sv


../src/Divisor_Alg2.sv
../src/arctan2.sv
../src/arctan4.sv
../src/DDS_rafa_red_cuarto.sv
../src/fixed_pkg.vhd
../src/memoria_dual_port.sv
../src/memoria_single_port_vhdl_2008_arctan.vhd
../src/nuevo_radicador_rapido2.sv
../src/premodulo_generico_mejor.sv

../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown.sv
../src/Control_path_dds_configurable_mejora_correlacion8_autoshunt_sweep_updown_4p.sv

../src/tb_comparacion_3p_vs_4p.sv
../src/tb_comparacion_3p_vs_4p_nettype.sv
../src/tb_comparacion_3p_vs_4p_portable.sv
../src/tb_comparacion_3p_vs_4p_portable_python.sv