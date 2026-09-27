onerror resume
wave tags  sim
wave update off
wave zoom range 566286864000 1502049192000
wave comment {ESTIMULO}
wave add tb_comparacion_3p_vs_4p_portable.adc1_data_4p -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave add tb_comparacion_3p_vs_4p_portable.adc2_data_4p -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave add tb_comparacion_3p_vs_4p_portable.adc3_data_4p -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave add tb_comparacion_3p_vs_4p_portable.adc1_data_3p -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave add tb_comparacion_3p_vs_4p_portable.adc2_data_3p -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave comment {BARRIDO}
wave add tb_comparacion_3p_vs_4p_portable.f_actual -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.z_bio_mag -tag sim -radix hexadecimal -representation twoscomplement -display analogzoom 19999.5 0
wave add tb_comparacion_3p_vs_4p_portable.mag_z_4p -tag sim -height 60 -radix hexadecimal -representation twoscomplement -display analogzoom 19999.5 0
wave add tb_comparacion_3p_vs_4p_portable.mag_z_3p -tag sim -radix hexadecimal -representation twoscomplement -display analogzoom 21961.7 0
wave add tb_comparacion_3p_vs_4p_portable.z_bio_fase -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave add tb_comparacion_3p_vs_4p_portable.fase_z_4p -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave add tb_comparacion_3p_vs_4p_portable.fase_z_3p -tag sim -radix hexadecimal -representation twoscomplement -display analogfull
wave comment {ERROR}
wave group GROUP1 -backgroundcolor #006666
wave add -group GROUP1 tb_comparacion_3p_vs_4p_portable.error_mag_4p -tag sim -radix hexadecimal -representation twoscomplement -display analogzoom 142.952 0
wave add -group GROUP1 tb_comparacion_3p_vs_4p_portable.error_mag_3p -tag sim -radix hexadecimal -representation twoscomplement -display analogzoom 142.952 0
wave insertion [expr [wave index insertpoint] + 1]
wave group GROUP1 -overlay -height 78 -minrange 0 -maxrange 142.952
wave insertion next
wave group GROUP0 -backgroundcolor #004466
wave add -group GROUP0 tb_comparacion_3p_vs_4p_portable.error_fase_4p -tag sim -radix hexadecimal -representation twoscomplement -display analogzoom 142.952 0
wave add -group GROUP0 tb_comparacion_3p_vs_4p_portable.error_fase_3p -tag sim -radix hexadecimal -representation twoscomplement -display analogzoom 142.952 0
wave insertion [expr [wave index insertpoint] + 1]
wave group GROUP0 -overlay -height 78 -minrange 0 -maxrange 142.952
wave insertion next
wave add tb_comparacion_3p_vs_4p_portable.clk125 -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.control_path_inst.incrementado -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.areset_n -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.start -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.dds_bus -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.fin -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.fin2 -tag sim -radix hexadecimal
wave add tb_comparacion_3p_vs_4p_portable.control_path_inst.state1 -tag sim -radix mnemonic
wave update on
wave top 0
wave marker add {Cursor 1} 0ps Yellow
