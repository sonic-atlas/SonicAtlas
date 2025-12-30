# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(sonic_recorder_library VERSION 0.0.1 LANGUAGES C)

add_library(sonic_recorder SHARED
  "context.c"
  "discovery.c"
  "capture.c"
  "vendor/miniaudio.c"
)

set_target_properties(sonic_recorder PROPERTIES
  PUBLIC_HEADER sonic_recorder.h
  OUTPUT_NAME "sonic_recorder"
)

target_compile_definitions(sonic_recorder PUBLIC DART_SHARED_LIB)

if (NOT MSVC)
    target_compile_options(sonic_recorder PRIVATE -O3 -msse2 -mavx2 -mfma)
endif()

if (WIN32)
    target_compile_definitions(sonic_recorder PRIVATE MA_ENABLE_WASAPI)
elseif (UNIX AND NOT APPLE AND NOT ANDROID)
    target_compile_definitions(sonic_recorder PRIVATE MA_ENABLE_ALSA MA_ENABLE_PULSEAUDIO)
    target_link_libraries(sonic_recorder PRIVATE dl pthread m)
endif()

target_compile_definitions(sonic_recorder PRIVATE 
    MA_ENABLE_ONLY_SPECIFIC_BACKENDS 
    MA_NO_ENGINE 
    MA_NO_GENERATION
)


