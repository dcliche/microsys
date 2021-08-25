A simple computer in SystemVerilog with a simulator.

The top module has the following devices:
- Xosera

Inputs:
- Reset button (hold F1 with the simulator)

Outputs:
- VGA 640x480 display using Xosera

# Requirements

- Verilator (4.205 or above)
- SDL2
- vasmm68k_mot

# Getting Started

The procedure to compile and start the simulator is the following:

- Clone the repository with the `recurse-submodules` flag:
```bash
git clone --recurse-submodules https://github.com/dcliche/microsys.git
cd microsys
```
Note: if the repository was cloned non-recursively previously, use `git submodule update --init` to clone the necessary submodules.

- `mkdir build; cd build`
- `cmake ..`
- `cmake --build .`
- `./top`
