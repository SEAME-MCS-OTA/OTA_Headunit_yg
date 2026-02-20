#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
#include <cstdlib>

int main(int argc, char *argv[]) {
    // headunit-ui runs as root on target; Chromium sandbox must be disabled.
    qputenv("QTWEBENGINE_DISABLE_SANDBOX", "1");
    // Demo fallback: keep web UI usable even when device time is wrong
    // and TLS verification would otherwise fail.
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS",
            "--no-sandbox --ignore-certificate-errors --allow-running-insecure-content");
    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
                     [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    engine.load(url);

    // On multi-output weston setups, force the window to the largest output.
    const auto roots = engine.rootObjects();
    if (!roots.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(roots.first());
        if (window) {
            const auto screens = QGuiApplication::screens();
            QScreen *bestScreen = nullptr;
            int bestArea = -1;
            for (QScreen *screen : screens) {
                const QRect g = screen->geometry();
                const int area = g.width() * g.height();
                if (area > bestArea) {
                    bestArea = area;
                    bestScreen = screen;
                }
            }
            if (bestScreen) {
                window->setScreen(bestScreen);
                window->setPosition(bestScreen->geometry().topLeft());
                window->showFullScreen();
            }
        }
    }

    return app.exec();
}
