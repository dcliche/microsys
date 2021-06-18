cmake_minimum_required(VERSION 3.12)

project(top)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(SDL2 REQUIRED COMPONENTS main)

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

# Create a new executable target that will contain all your sources
add_executable(top sim/sim_main.cpp)
target_link_libraries(top PRIVATE SDL2)

# Add the Verilated circuit to the target
verilate(top COVERAGE TRACE
  INCLUDE_DIRS "./rtl"
  SOURCES ./rtl/top.sv)