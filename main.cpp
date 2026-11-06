#include "Account.h"
#include "Category.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>

using namespace core::model;

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("UI", "Main");

    return QGuiApplication::exec();
}
