# Ejecuta este script una vez para generar la .so/.dll y el paquete SV
from pysv import sv, compile_lib, generate_sv_binding
import pysv
import pysv.codegen as pysv_codegen
from pathlib import Path
import shutil
import os
import platform


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

class Filt:
    def __init__(self):
        self.y = 0.0
        self.a = 0.5

    @sv()  # permite configurar alpha desde SV
    def set_alpha(self, alpha: float) -> None:
        self.a = alpha

    @sv()  # expone el método a SV
    def step(self, x: float) -> float:
        self.y = self.a*self.y + (1-self.a)*x
        return self.y

if __name__ == "__main__":
    _fix_pysv_cmake_minimum()
    _force_x64_cmake_on_windows()
    _patch_pysv_codegen_for_windows()
    shutil.rmtree("build/build", ignore_errors=True)
    try:
        lib_path = compile_lib([Filt], cwd="build")                 # compila lib compartida DPI
    except FileNotFoundError:
        build_root = Path("build") / "build"
        candidates = sorted(build_root.glob("**/libpysv.so"))
        if not candidates:
            raise
        built_lib = candidates[-1]
        dst_lib = Path("build") / "libpysv.so"
        shutil.copy2(built_lib, dst_lib)
        lib_path = str(dst_lib)
    generate_sv_binding([Filt], filename="filt_pkg.sv", pkg_name="filt_pkg")
    print("Built:", lib_path, "and filt_pkg.sv")