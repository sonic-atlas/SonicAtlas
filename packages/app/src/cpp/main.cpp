#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include "AudioFileManager.h"
#include "AudioPlayer.h"
#include "ThemeManager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    // Create managers
    ThemeManager themeManager;
    AudioPlayer audioPlayer;
    AudioFileManager audioFileManager;

    // Register with QML
    engine.rootContext()->setContextProperty("themeManager", &themeManager);
    engine.rootContext()->setContextProperty("audioPlayer", &audioPlayer);
    engine.rootContext()->setContextProperty("audioFileManager", &audioFileManager);

    // Load audio files from current directory
    QString currentDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    audioFileManager.loadFilesFromDirectory(currentDir);

    // Load main QML
    const QUrl url(QStringLiteral("qrc:/qt/qml/SonicAtlasApp/src/qml/Main.qml"));
    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
