cmake_minimum_required(VERSION 3.12)

project(top)

include(cmake/FindSDL2.cmake)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

# Create a new executable target that will contain all your sources
add_executable(top sim/sim_main.cpp)
target_include_directories(top PRIVATE ${SDL2_INCLUDE_DIR})
target_link_libraries(top PRIVATE ${SDL2_LIBRARY})

# Add the Verilated circuit to the target
verilate(top TRACE
  OPT_FAST
  INCLUDE_DIRS "./rtl"
  SOURCES ./rtl/top.sv)