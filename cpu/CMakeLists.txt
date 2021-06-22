cmake_minimum_required(VERSION 3.12)

project(cpu)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

# Create a new executable target that will contain all your sources
add_executable(cpu sim/sim_cpu.cpp)

# Add the Verilated circuit to the target
verilate(cpu COVERAGE TRACE
  INCLUDE_DIRS "./rtl"
  SOURCES ./rtl/microaddr.sv ./rtl/microaddr_counter.sv)