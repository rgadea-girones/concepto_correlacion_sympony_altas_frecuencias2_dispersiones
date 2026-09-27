# dpi_pysv/dataframe_sink.py
from typing import List, Optional, Tuple
import pandas as pd
import os
import platform
import shutil
from pathlib import Path
import pysv
import pysv.codegen as pysv_codegen
from pysv import sv, compile_lib, generate_sv_binding  # pysv genera el binding DPI automáticamente


def _fix_pysv_cmake_minimum() -> None:
    cmake_tpl = Path(pysv.__file__).resolve().parent / "CMakeLists.txt"
    if not cmake_tpl.exists():
        return
    content = cmake_tpl.read_text(encoding="utf-8")
    old = "cmake_minimum_required(VERSION 3.4)"
    if old in content:
        cmake_tpl.write_text(content.replace(old, "cmake_minimum_required(VERSION 3.5)"), encoding="utf-8")


def _force_x64_cmake_on_windows() -> None:
    if platform.system() != "Windows":
        return
    os.environ["CMAKE_GENERATOR_PLATFORM"] = "x64"
    os.environ["CMAKE_GENERATOR"] = "Visual Studio 15 2017"
    os.environ["CMAKE_GENERATOR_TOOLSET"] = "v141"


def _patch_pysv_codegen_for_windows() -> None:
    if platform.system() != "Windows":
        return
    pysv_codegen.__DEFAULT_ATTRIBUTE = "__declspec(dllexport) "
    pysv_codegen.should_add_sys_path = lambda _func_defs: False

class DataCollector:
    """
    Colector en RAM:
            - buffer_rows: acumula filas compactas en memoria (tuplas)
            - DataFrame se construye sólo al guardar a disco (por medida)
    """
    def __init__(self):
        self.columns: Optional[List[str]] = ["sujeto", "medida", "frecuencia", "modulo", "fase"]
        self.batch_size = 1000
        self.buffer_rows: List[Tuple[int, int, int, int, int]] = []
        self.output_csv = "datos_simulacion_nuevo.csv"

    @sv()
    def set_batch_size(self, batch_size: int) -> None:
        """Configura el tamaño de lote en runtime."""
        if batch_size <= 0:
            raise ValueError("batch_size debe ser > 0")
        self.batch_size = int(batch_size)

    @sv()
    def start(self) -> None:
        """Inicializa/limpia el acumulador en RAM."""
        self.buffer_rows.clear()

    @sv()
    def add_sample_scaled(self, sujeto: int, medida: int, frecuencia_milli: int, modulo_milli: int, fase_milli: int) -> None:
        """Añade una fila usando valores escalados x1000 para evitar tipos string/real en el binding PySV."""
        self.buffer_rows.append((
            int(sujeto),
            int(medida),
            int(frecuencia_milli),
            int(modulo_milli),
            int(fase_milli)
        ))

    @sv()
    def flush(self) -> int:
        """Compatibilidad API: devuelve filas en RAM."""
        return int(len(self.buffer_rows))

    @sv()
    def count(self) -> int:
        """Filas acumuladas en RAM."""
        return int(len(self.buffer_rows))

    @sv()
    def reset_output_file(self) -> None:
        """Borra el CSV de salida al inicio de una simulación."""
        if os.path.exists(self.output_csv):
            os.remove(self.output_csv)

    @sv()
    def save_to_csv(self) -> int:
        """Guarda en disco lo acumulado (RAM) y reinicia el acumulador para la siguiente medida."""
        if not self.buffer_rows:
            return 0

        df = pd.DataFrame(self.buffer_rows, columns=self.columns)
        df["frecuencia"] = df["frecuencia"] / 1000.0
        df["modulo"] = df["modulo"] / 1000.0
        df["fase"] = df["fase"] / 1000.0

        append_mode = os.path.exists(self.output_csv)
        df.to_csv(self.output_csv, mode='a' if append_mode else 'w', header=not append_mode, index=False)
        saved_rows = int(len(df))
        self.buffer_rows.clear()
        return saved_rows

if __name__ == "__main__":
    # Construye la librería DPI y el paquete SystemVerilog
    script_dir = Path(__file__).resolve().parent
    build_dir = script_dir / "build"
    out_pkg = script_dir / "df_pkg.sv"

    _fix_pysv_cmake_minimum()
    _force_x64_cmake_on_windows()
    _patch_pysv_codegen_for_windows()
    shutil.rmtree(build_dir / "build", ignore_errors=True)

    try:
        lib_path = compile_lib([DataCollector], cwd=str(build_dir))
    except FileNotFoundError:
        build_root = build_dir / "build"
        candidates = sorted(build_root.glob("**/libpysv.so"))
        if not candidates:
            raise
        built_lib = candidates[-1]
        dst_lib = build_dir / "libpysv.so"
        shutil.copy2(built_lib, dst_lib)
        lib_path = str(dst_lib)

    if platform.system() == "Windows":
        lib_path_obj = Path(lib_path)
        if lib_path_obj.suffix.lower() == ".so":
            dll_path = lib_path_obj.with_suffix(".dll")
            shutil.copy2(lib_path_obj, dll_path)
            print("Windows DLL alias created:", dll_path)

    generate_sv_binding([DataCollector], filename=str(out_pkg), pkg_name="df_pkg")
    print("Built:", lib_path, "and", out_pkg)