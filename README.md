A simple computer in System Verilog with a simulator. The top module has the following devices:
- RAM
- 8-bit CPU

Inputs:
None.

Outputs:
- 8 LEDs

CPU based on http://labs.domipheus.com/blog/designing-a-cpu-in-vhdl-part-1-rationale-tools-method/

# Requirements

- Verilator (4.205 or above)
- SDL2
- Python3
- Optional: Icarus Verilog (11.0 or above)

# Getting Started

The procedure to compile and start the simulator is the following:

- `mkdir build; cd build`
- `cmake ..`
- `cmake --build .`
- `python3 ../tools/as01.py ../src/test/test.asm ram.hex`
- `./top`
