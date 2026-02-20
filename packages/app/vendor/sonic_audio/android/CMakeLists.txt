cmake_minimum_required(VERSION 3.10)
project(sonic_audio_android)

get_filename_component(ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
message(STATUS "SonicAudio Android: ROOT_DIR=${ROOT_DIR}")
message(STATUS "SonicAudio Android: CMAKE_ANDROID_ARCH_ABI=${CMAKE_ANDROID_ARCH_ABI}")

set(DEPENDENCIES_ROOT "${ROOT_DIR}/dependencies/android/${CMAKE_ANDROID_ARCH_ABI}")

add_subdirectory("${ROOT_DIR}/src" sonic_audio_build)