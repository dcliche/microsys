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
add_executable(top 
  sim/sim_main.cpp
  sim/m68kcpu.c
  sim/m68kdasm.c
  sim/m68kops.c
  sim/softfloat/softfloat.c
  ${CMAKE_CURRENT_BINARY_DIR}/test.bin
)
target_include_directories(top PRIVATE ${SDL2_INCLUDE_DIR})
target_link_libraries(top PRIVATE ${SDL2_LIBRARY})

# Add the Verilated circuit to the target
verilate(top TRACE
  OPT_FAST
  INCLUDE_DIRS "./rtl;external/Xosera/rtl"
  SOURCES
    ./rtl/top.sv
    external/Xosera/rtl/xosera_main.sv
  TOP_MODULE "top"
  VERILATOR_ARGS
    "-Wno-WIDTH"
  )

configure_file(${CMAKE_SOURCE_DIR}/external/Xosera/rtl/fonts/font_ST_8x8w.mem ${CMAKE_CURRENT_BINARY_DIR}/fonts/font_ST_8x8w.mem COPYONLY)
configure_file(${CMAKE_SOURCE_DIR}/external/Xosera/rtl/fonts/font_ST_8x16w.mem ${CMAKE_CURRENT_BINARY_DIR}/fonts/font_ST_8x16w.mem COPYONLY)
configure_file(${CMAKE_SOURCE_DIR}/external/Xosera/rtl/fonts/hexfont_8x8w.mem ${CMAKE_CURRENT_BINARY_DIR}/fonts/hexfont_8x8w.mem COPYONLY)
configure_file(${CMAKE_SOURCE_DIR}/external/Xosera/rtl/default_colors.mem ${CMAKE_CURRENT_BINARY_DIR}/default_colors.mem COPYONLY)
configure_file(${CMAKE_SOURCE_DIR}/external/Xosera/rtl/default_sprite.mem ${CMAKE_CURRENT_BINARY_DIR}/default_sprite.mem COPYONLY)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/test.bin
    DEPENDS ${CMAKE_SOURCE_DIR}/src/test/test.asm
    COMMAND vasmm68k_mot -Fbin -m68010 -wfail ${CMAKE_SOURCE_DIR}/src/test/test.asm -o ${CMAKE_CURRENT_BINARY_DIR}/test.bin
)
