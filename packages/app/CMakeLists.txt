cmake_minimum_required(VERSION 3.22...4.3)
project(SonicAtlas LANGUAGES CXX)


set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
set(CMAKE_SUPPRESS_DEVELOPER_WARNINGS TRUE CACHE BOOL "" FORCE)
set(Qt6TaskTree_FOUND TRUE CACHE BOOL "" FORCE)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Network Quick Qml QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0002 NEW)
qt_policy(SET QTP0004 NEW)

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS src/*.cpp src/*.hpp)
qt_add_executable(${PROJECT_NAME} ${SOURCES})
set_target_properties(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set_source_files_properties(src/ui/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(${PROJECT_NAME}
        URI SonicAtlas
        VERSION 1.0
        QML_FILES
        src/ui/Theme.qml
        src/ui/Main.qml
)

qt_add_resources(${PROJECT_NAME} "app_icons"
        PREFIX "/"
        FILES
        assets/icon/icon.png
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)
target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::Core Qt6::Gui Qt6::Network Qt6::Quick Qt6::Qml Qt6::QuickControls2)

target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra -Wpedantic -Werror)

if (ANDROID)
    set_target_properties(${PROJECT_NAME} PROPERTIES
            QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/android
            QT_ANDROID_PACKAGE_NAME "dev.heggo.sonic_atlas"
            QT_ANDROID_MIN_SDK_VERSION 27
            QT_ANDROID_TARGET_SDK_VERSION 36
            QT_ANDROID_COMPILE_SDK_VERSION 36
    )
elseif (UNIX)
    include(GNUInstallDirs)
    install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES assets/icon/icon.png
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/256x256/apps
            RENAME SonicAtlas.png)
endif()
