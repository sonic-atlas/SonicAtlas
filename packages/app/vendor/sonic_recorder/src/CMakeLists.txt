# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(sonic_recorder_library VERSION 0.0.1 LANGUAGES C)

add_library(sonic_recorder SHARED
  "sonic_recorder.c"
)

set_target_properties(sonic_recorder PROPERTIES
  PUBLIC_HEADER sonic_recorder.h
  OUTPUT_NAME "sonic_recorder"
)

target_compile_definitions(sonic_recorder PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(sonic_recorder PRIVATE "-Wl,-z,max-page-size=16384")
endif()
