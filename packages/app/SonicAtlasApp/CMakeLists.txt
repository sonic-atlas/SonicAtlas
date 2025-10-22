cmake_minimum_required(VERSION 3.16)

project(SonicAtlasApp VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS
    Quick
    Multimedia
    Network
)
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(Qt6 REQUIRED COMPONENTS Core)

qt_standard_project_setup(REQUIRES 6.8)

set(PROJECT_SOURCES
    src/cpp/main.cpp
    src/cpp/ColorUtils.h src/cpp/ColorUtils.cpp
    src/cpp/ThemeManager.h src/cpp/ThemeManager.cpp
    src/cpp/AudioPlayer.h src/cpp/AudioPlayer.cpp
    src/cpp/AudioFileManager.h src/cpp/AudioFileManager.cpp
)

qt_add_executable(appSonicAtlasApp
    ${PROJECT_SOURCES}
)

qt_add_qml_module(appSonicAtlasApp
    URI SonicAtlasApp
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
        src/qml/Theme.qml
        src/qml/components/SearchBar.qml
        src/qml/components/TrackCard.qml
        src/qml/pages/PlayerPage.qml
        src/qml/pages/SearchPage.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appSonicAtlasApp PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appSonicAtlasApp
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appSonicAtlasApp
    PRIVATE
        Qt6::Quick
        Qt6::Multimedia
        Qt6::Network
)
target_link_libraries(appSonicAtlasApp PRIVATE Qt6::Core)
target_link_libraries(appSonicAtlasApp PRIVATE Qt6::Core)
target_link_libraries(appSonicAtlasApp PRIVATE Qt6::Core)

include(GNUInstallDirs)
install(TARGETS appSonicAtlasApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
