cmake_minimum_required(VERSION 3.15)
project(sonic_atlas_backend LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

file(GLOB_RECURSE CONTROLLERS controllers/*.cpp)
file(GLOB_RECURSE UTILS utils/*.cpp)
file(GLOB_RECURSE FILTERS filters/*.cpp)

find_package(Drogon CONFIG REQUIRED)
find_package(jwt-cpp CONFIG REQUIRED)

add_executable(sonic_atlas_backend main.cpp ${CONTROLLERS} ${FILTERS} ${UTILS})
target_include_directories(sonic_atlas_backend PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(sonic_atlas_backend PRIVATE Drogon::Drogon jwt-cpp::jwt-cpp)

if (MSVC)
    target_compile_options(sonic_atlas_backend PRIVATE /W4 /WX)
    target_compile_definitions(sonic_atlas_backend PRIVATE _CRT_SECURE_NO_WARNINGS)
else()
    target_compile_options(sonic_atlas_backend PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

add_custom_command(TARGET sonic_atlas_backend POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/config.json
        $<TARGET_FILE_DIR:sonic_atlas_backend>/config.json
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/.env
        $<TARGET_FILE_DIR:sonic_atlas_backend>/.env
)
