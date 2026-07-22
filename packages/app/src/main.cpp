#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char* argv[]) {
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");
    QGuiApplication app(argc, argv);
    QGuiApplication::setDesktopFileName("dev.heggo.sonic_atlas");
    QGuiApplication::setWindowIcon(QIcon(":/assets/icon/icon.png"));

    QQuickStyle::setStyle("Material");

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("SonicAtlas", "Main");

    return QGuiApplication::exec();
}
