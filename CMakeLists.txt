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
add_executable(top sim/sim_main.cpp ${CMAKE_CURRENT_BINARY_DIR}/ram.hex)
target_include_directories(top PRIVATE ${SDL2_INCLUDE_DIR})
target_link_libraries(top PRIVATE ${SDL2_LIBRARY})

# Add the Verilated circuit to the target
verilate(top TRACE
  OPT_FAST
  INCLUDE_DIRS "./rtl"
  SOURCES
    ./rtl/top.sv
    external/projf-explore/lib/essential/debounce.sv
    external/projf-explore/lib/memory/rom_sync.sv
    external/projf-explore/lib/memory/rom_async.sv
    external/projf-explore/lib/display/display_timings_480p.sv
    external/projf-explore/graphics/hardware-sprites/sprite.sv
  VERILATOR_ARGS
    "-Wno-WIDTH"
  )

configure_file(${CMAKE_SOURCE_DIR}/data/hedgehog.mem ${CMAKE_CURRENT_BINARY_DIR}/hedgehog.mem COPYONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/hedgehog_palette.mem ${CMAKE_CURRENT_BINARY_DIR}/hedgehog_palette.mem COPYONLY)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ram.hex
    DEPENDS ${CMAKE_SOURCE_DIR}/src/test/test.asm
    COMMAND node ${CMAKE_SOURCE_DIR}/external/nanoasm/src/asmmain.js ${CMAKE_SOURCE_DIR}/src/microsys.json  ${CMAKE_SOURCE_DIR}/src/test/test.asm > ${CMAKE_CURRENT_BINARY_DIR}/ram.hex
)