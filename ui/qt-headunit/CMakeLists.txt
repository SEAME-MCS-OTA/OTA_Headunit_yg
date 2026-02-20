cmake_minimum_required(VERSION 3.16)
project(headunit-ui VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network WebEngineQuick)

qt_add_executable(headunit-ui
    src/main.cpp
    qml/qml.qrc
)

target_link_libraries(headunit-ui
    PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network Qt6::WebEngineQuick
)

install(TARGETS headunit-ui RUNTIME DESTINATION /usr/bin)
install(FILES systemd/headunit.service DESTINATION /usr/lib/systemd/system)
