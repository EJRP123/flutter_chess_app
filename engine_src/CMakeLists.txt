# To execute c_make command, make sure to be in the ./engine_src folder
# To clean cmake files: cmake --build ./build --config Debug --target clean --
# To build the library: cmake --build ./build --config Debug --target all --
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
