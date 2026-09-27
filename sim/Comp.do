# Compile vhdl file
proc comp {filename} {
  if {[file exists ${filename}] == 1} {
   puts "## vlog $filename"
   vlog +incdir+../src -sv -quiet ${filename} -work work -lint
   #vcom -2008 -novopt -quiet ${filename} -work work -lint
  } else {
   puts "## WARNING: File not found: ${filename}"
  }
}

# Create library "work" if necessary
catch {vlib work}

# Leer la lista de archivos desde un fichero
set filelist "filelist.txt"
if {[file exists $filelist]} {
  set fp [open $filelist r]
  while {[gets $fp line] >= 0} {
    # Ignorar líneas vacías o comentarios
    if {[string trim $line] ne "" && ![string match "#*" $line]} {
      comp $line
    }
  }
  close $fp
} else {
  puts "## ERROR: No se encontró el archivo $filelist"
}
