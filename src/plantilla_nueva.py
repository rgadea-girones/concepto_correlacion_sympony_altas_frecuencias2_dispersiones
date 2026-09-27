from pysv import sv, compile_lib, generate_sv_binding

class Filt:
    def __init__(self):          # <- solo self
        self.y = 0.0
        self.a = 0.5

    @sv()
    def set_alpha(self, alpha: float) -> None:
        self.a = alpha

    @sv()
    def step(self, x: float) -> float:
        self.y = self.a * self.y + (1 - self.a) * x
        return self.y

class Gain:
    def __init__(self):          # <- solo self
        self.k = 1.0

    @sv()
    def set_gain(self, k: float) -> None:
        self.k = k

    @sv()
    def apply(self, x: float) -> float:
        return self.k * x

if __name__ == "__main__":
    classes = [Filt, Gain]       # <- agrega aquí nuevas clases
    lib_path = compile_lib(classes, cwd="build")
    generate_sv_binding(classes, filename="filt_pkg.sv", pkg_name="filt_pkg")
    print("Built:", lib_path, "and filt_pkg.sv")