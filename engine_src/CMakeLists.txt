# ON WINDOWS: Commands to run to get the .dll
# Note: Use MinGW to get the gcc executable
# cd ./engine_src/src
# gcc -c fenString.c moveGenerator.c
# gcc -shared -o chess_engine.dll fenString.o moveGenerator.o
# You then move the files into the ./lib/engine folder

# ON LINUS: Use CMake to create the .so files
# cd ./engine_src/
# To clean cmake files: cmake --build ./build --config Debug --target clean --
# To build the library: cmake --build ./build --config Debug --target all --
# You then move the files into the ./lib/engine folder

cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(chess_engine_library VERSION 1.0.0 LANGUAGES C)
add_library(chess_engine_library SHARED 
    src/moveGenerator.c
    src/fenString.c
    )

set_target_properties(chess_engine_library PROPERTIES
    PUBLIC_HEADER moveGenerator.h
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
    OUTPUT_NAME "chess_engine"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Hex_Identity_ID_Goes_Here"
)
