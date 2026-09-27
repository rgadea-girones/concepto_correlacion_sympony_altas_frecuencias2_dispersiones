`ifndef PYSV_DF_PKG
`define PYSV_DF_PKG
package df_pkg;
import "DPI-C" function chandle DataCollector_pysv_init();
import "DPI-C" function void DataCollector_add_sample_scaled(input chandle self,
                                                             input int sujeto,
                                                             input int medida,
                                                             input int frecuencia_milli,
                                                             input int modulo_milli,
                                                             input int fase_milli);
import "DPI-C" function int DataCollector_count(input chandle self);
import "DPI-C" function void DataCollector_destroy(input chandle self);
import "DPI-C" function int DataCollector_flush(input chandle self);
import "DPI-C" function void DataCollector_reset_output_file(input chandle self);
import "DPI-C" function int DataCollector_save_to_csv(input chandle self);
import "DPI-C" function void DataCollector_set_batch_size(input chandle self,
                                                          input int batch_size);
import "DPI-C" function void DataCollector_start(input chandle self);
import "DPI-C" function void pysv_finalize();
class PySVObject;
chandle pysv_ptr;
endclass
class DataCollector extends PySVObject;
  function new();
    pysv_ptr = DataCollector_pysv_init();
  endfunction
  function void add_sample_scaled(input int sujeto,
                                  input int medida,
                                  input int frecuencia_milli,
                                  input int modulo_milli,
                                  input int fase_milli);
    DataCollector_add_sample_scaled(pysv_ptr, sujeto, medida, frecuencia_milli, modulo_milli, fase_milli);
  endfunction
  function int count();
    return DataCollector_count(pysv_ptr);
  endfunction
  function void destroy();
    DataCollector_destroy(pysv_ptr);
  endfunction
  function int flush();
    return DataCollector_flush(pysv_ptr);
  endfunction
  function void reset_output_file();
    DataCollector_reset_output_file(pysv_ptr);
  endfunction
  function int save_to_csv();
    return DataCollector_save_to_csv(pysv_ptr);
  endfunction
  function void set_batch_size(input int batch_size);
    DataCollector_set_batch_size(pysv_ptr, batch_size);
  endfunction
  function void start();
    DataCollector_start(pysv_ptr);
  endfunction
endclass
endpackage
`endif // PYSV_DF_PKG
