A simple computer in SystemVerilog with a simulator.

Uses the libraries from Project F (https://projectf.io/).

The top module has the following devices:
- RAM
- 8-bit CPU
- Pong module
- Sprite

Inputs:
- 4 switches (key 1 to 4 to toggle with the simulator)
- Reset button (hold F1 with the simulator)
- Up and down buttons
- Control button (TAB key with the simulator)

Outputs:
- 4 LEDs
- VGA 640x480 display

# Requirements

- Verilator (4.205 or above)
- SDL2
- Python3

# Getting Started

The procedure to compile and start the simulator is the following:

- Clone the repository with the `recurse-submodules` flag:
```bash
git clone --recurse-submodules https://github.com/dcliche/microsys.git
cd tvge
```
Note: if the repository was cloned non-recursively previously, use `git submodule update --init` to clone the necessary submodules.

- `mkdir build; cd build`
- `cmake ..`
- `cmake --build .`
- `python3 ../tools/as01.py ../src/test/test.asm ram.hex`
- `./top`
