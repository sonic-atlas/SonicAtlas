cmake_minimum_required(VERSION 3.10)
project(sonic_audio LANGUAGES C CXX)

get_filename_component(ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(FFMPEG_ROOT "${ROOT_DIR}/ffmpeg/windows-x64")

add_subdirectory("${ROOT_DIR}/src" sonic_audio_build)

set(PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:sonic_audio> PARENT_SCOPE)

file(GLOB FFMPEG_DLLS "${FFMPEG_ROOT}/bin/*.dll")

foreach (DLL_PATH ${FFMPEG_DLLS})
    get_filename_component(DLL_NAME ${DLL_PATH} NAME)
    add_custom_command(TARGET sonic_audio POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${DLL_PATH}"
            "$<TARGET_FILE_DIR:sonic_audio>/${DLL_NAME}"
    )
endforeach ()