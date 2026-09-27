`ifndef PYSV_FILT_PKG
`define PYSV_FILT_PKG
package filt_pkg;
import "DPI-C" function chandle Filt_pysv_init();
import "DPI-C" function void Filt_destroy(input chandle self);
import "DPI-C" function void Filt_set_alpha(input chandle self,
                                            input int alpha);
import "DPI-C" function int Filt_step(input chandle self,
                                      input int x);
import "DPI-C" function void pysv_finalize();
class PySVObject;
chandle pysv_ptr;
endclass
class Filt extends PySVObject;
  function new();
    pysv_ptr = Filt_pysv_init();
  endfunction
  function void destroy();
    Filt_destroy(pysv_ptr);
  endfunction
  function void set_alpha(input int alpha);
    Filt_set_alpha(pysv_ptr, alpha);
  endfunction
  function int step(input int x);
    return Filt_step(pysv_ptr, x);
  endfunction
endclass
endpackage
`endif // PYSV_FILT_PKG
