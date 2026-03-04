set(SOURCE_FILES
        sonic_audio.h
        internal.h
        common/context.c
        common/discovery.c
        recorder/capture.c
        player/decoder.h
        player/decoder.c
        player/player.c
        thread/sonic_thread.h
        thread/sonic_thread_types.h
        vendor/miniaudio.c
)

add_library(sonic_audio SHARED ${SOURCE_FILES})

target_compile_definitions(sonic_audio PRIVATE
        MA_ENABLE_ONLY_SPECIFIC_BACKENDS
        MA_ENABLE_WASAPI
        MA_ENABLE_WINMM
        MA_ENABLE_ALSA
        MA_ENABLE_PULSEAUDIO
        MA_ENABLE_AAUDIO
        MA_ENABLE_OPENSL
        MA_NO_DECODING
        MA_NO_ENCODING
        MA_NO_FLAC
        MA_NO_MP3
)

if (WIN32)
    target_compile_definitions(sonic_audio PRIVATE WIN32_LEAN_AND_MEAN)
else ()
    target_compile_definitions(sonic_audio PRIVATE _POSIX_C_SOURCE=200809L _DEFAULT_SOURCE)
    if (NOT ANDROID)
        target_compile_options(sonic_audio PRIVATE -msse2 -mavx2)
    endif ()
endif ()

if (NOT DEFINED DEPENDENCIES_ROOT)
    message(FATAL_ERROR "DEPENDENCIES_ROOT must be defined before including src/CMakeLists.txt")
endif ()

message(STATUS "Linking FFmpeg from: ${DEPENDENCIES_ROOT}")

target_include_directories(sonic_audio PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor
        ${DEPENDENCIES_ROOT}/include
)

if (ANDROID)
    set(AVFORMAT_LIB "${DEPENDENCIES_ROOT}/lib/libavformat.a")
    set(AVCODEC_LIB "${DEPENDENCIES_ROOT}/lib/libavcodec.a")
    set(AVUTIL_LIB "${DEPENDENCIES_ROOT}/lib/libavutil.a")
    set(SWRESAMPLE_LIB "${DEPENDENCIES_ROOT}/lib/libswresample.a")
else ()
    find_library(AVFORMAT_LIB NAMES avformat libavformat PATHS ${DEPENDENCIES_ROOT}/lib NO_DEFAULT_PATH)
    find_library(AVCODEC_LIB NAMES avcodec libavcodec PATHS ${DEPENDENCIES_ROOT}/lib NO_DEFAULT_PATH)
    find_library(AVUTIL_LIB NAMES avutil libavutil PATHS ${DEPENDENCIES_ROOT}/lib NO_DEFAULT_PATH)
    find_library(SWRESAMPLE_LIB NAMES swresample libswresample PATHS ${DEPENDENCIES_ROOT}/lib NO_DEFAULT_PATH)
endif ()

target_link_libraries(sonic_audio PRIVATE
        ${AVFORMAT_LIB}
        ${AVCODEC_LIB}
        ${AVUTIL_LIB}
        ${SWRESAMPLE_LIB}
)

if (WIN32)
    target_link_libraries(sonic_audio PRIVATE User32 Ole32 Bcrypt)
elseif (ANDROID)
    set(SSL_LIB "${DEPENDENCIES_ROOT}/lib/libssl.a")
    set(CRYPTO_LIB "${DEPENDENCIES_ROOT}/lib/libcrypto.a")
    target_link_libraries(sonic_audio PRIVATE log android OpenSLES aaudio z ${SSL_LIB} ${CRYPTO_LIB})
    target_link_options(sonic_audio PRIVATE -Wl,-z,max-page-size=16384)
else ()
    set(SSL_LIB "${DEPENDENCIES_ROOT}/lib/libssl.a")
    set(CRYPTO_LIB "${DEPENDENCIES_ROOT}/lib/libcrypto.a")
    target_link_libraries(sonic_audio PRIVATE m pthread dl ${SSL_LIB} ${CRYPTO_LIB})
    target_link_options(sonic_audio PRIVATE -Wl,-z,notext)
endif ()

set_target_properties(sonic_audio PROPERTIES C_VISIBILITY_PRESET hidden)