$ErrorActionPreference = "Stop"

$svpy = "C:\Users\rgadea\AppData\Local\miniconda3\envs\svpy"
$workspace = Split-Path -Parent $PSScriptRoot
$libDir = Join-Path $workspace "src\build"

if (-not (Test-Path (Join-Path $libDir "libpysv.dll"))) {
    throw "No se encontró libpysv.dll en $libDir"
}

$env:PATH = "$libDir;$svpy;$svpy\Library\bin;$svpy\DLLs;$env:PATH"

Write-Host "PATH preparado para PySV/Questa"
Write-Host "Ejecutando: qrun -f qrun_batch_pysv.f"
qrun -f qrun_batch_pysv.f
