  -uvm 
  -sv 
   -gui
   -visualizer
   -fcov
   -debug
   -qwavedb=+signal+class+transaction+msg=error,pa
  -top top
  +incdir+../src/
  +UVM_TESTNAME=test_fifo
  +UVM_VERBOSITY=UVM_MEDIUM 
  +UVM_RECORDING_SETUP
  -l qrun.log 
 -sv_root C:/questasim64_2025.1_2/uvm-1.1d/win64 
 -sv_lib uvm_dpi
  -cover bst

../src/agente_fifo_pkg.sv
../src/env_fifo_pkg.sv
../src/sequences_pkg.sv
../src/virtual_sequences_pkg.sv
../src/test_pkg.sv
../src/fifo_no_sintetizable_mejor.sv
../src/clock_reset.sv
../src/top_duv.sv
../src/if_fifo.sv
../src/top.sv
