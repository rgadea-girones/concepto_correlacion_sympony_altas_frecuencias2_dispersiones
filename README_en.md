# Proof of Concept: Clean Correlation Symphony (Nettype vs Symphony Deluxe)

This directory contains the simulation environment and data analysis scripts to compare the performance and accuracy of a bioimpedance system simulation using two different approaches:
1. **Fast simulation with Nettype (RNM):** Using the pure digital engine of Questa.
2. **Mixed-signal/analog simulation with Symphony (Deluxe option):** Using the AFS analog solver.

## Main Simulation Tasks

The workflow is based on VS Code tasks defined in the workspace (or executable via equivalent scripts):

- **Simulate batch rafa nettype:** Launches the complete system simulation using Nettype models (fast, purely based on digital events).
- **Simulate batch rafa symphony deluxe:** Launches the complete simulation in co-simulation mode using Symphony Deluxe, integrating real Verilog-AMS models and the analog kernel.

## Experiments and Measurements

The main objective is to perform complete measurements with both testbenches to contrast them against each other.

A particularly interesting experiment covered in this environment is the impact of the **Autoshunt** circuit:
- **Simulations without Autoshunt:** Show significant oscillations and errors at low frequencies.
- **Simulations with Autoshunt:** Correct these errors, stabilizing the response at low frequencies.

These experiments (with and without autoshunt) were executed in both Nettype and Symphony, demonstrating not only the need for the autoshunt, but also the high correlation that Nettype maintains with respect to the real model (Symphony/Golden) once these dynamic dependencies are managed.

## Data Analysis (Python Scripts in `/sim`)

Inside the `sim/` folder you will find the organized structure of the experiment and the Python scripts:

### Results Directory Structure
To facilitate peer review, repository hosting, and the organization of the published material, the results have been structured into the following folders:
- `/sim/datos_simulacion/`: Contains all the original raw data directly extracted from the full simulations (Nettype and Symphony) in `.csv` format.
- `/sim/resultados_graficas/`: Includes all `.png` figures (linear and logarithmic scales, phase/magnitude diagrams) ready to be attached to the review manuscript.
- `/sim/tablas_comparativas/`: Comprises detailed metrics in statistical `.csv` files (MAE, RMSE, error percentage per decade, and maximum error points) along with condensed tables in `.md` for quick reading of the consolidated results (with and without autoshunt).

### Visualization Scripts
- `comparar_nettype_vs_symphony_golden.py` / `comparar_nettype_vs_symphony_golden_relativo.py`: Evaluate the full simulations against their respective Golden versions, generating the outputs found in `resultados_graficas/` and `tablas_comparativas/`.
- `comparar_autoshunt_reducido_sujeto0.py` / `comparar_autoshunt_reducido_sujeto0_logy.py`: Generate dedicated metrics to specifically verify the accuracy improvement provided by the **Autoshunt** circuit, paying special attention to low frequencies.

### Virtual Environment

It is recommended to use the created virtual environment (`sim/.venv_articulo_plots`) to execute the visualization scripts, as it contains key dependencies such as `pandas`, `numpy`, and `matplotlib`.