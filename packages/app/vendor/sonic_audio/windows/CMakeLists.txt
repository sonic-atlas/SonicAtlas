cmake_minimum_required(VERSION 3.10)
project(sonic_audio LANGUAGES C CXX)

get_filename_component(ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(FFMPEG_ROOT "${ROOT_DIR}/ffmpeg/windows-x64")

add_subdirectory("${ROOT_DIR}/src" sonic_audio_build)

file(GLOB FFMPEG_DLLS
    "${FFMPEG_ROOT}/bin/*.dll"
)

set(PLUGIN_BUNDLED_LIBRARIES
    $<TARGET_FILE:sonic_audio>
    ${FFMPEG_DLLS}
    PARENT_SCOPE
)
