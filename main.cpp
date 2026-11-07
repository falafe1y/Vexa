#include "LedgerService.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName(
        QStringLiteral("Vexa")
        );

    QCoreApplication::setApplicationName(
        QStringLiteral("Vexa")
        );

    const QString dataDirectory =
        QStandardPaths::writableLocation(
            QStandardPaths::AppDataLocation
            );

    if (dataDirectory.isEmpty() ||
        !QDir{}.mkpath(dataDirectory)) {
        qCritical() << "Не удалось создать каталог данных:"
                    << dataDirectory;

        return 1;
    }

    const QString databasePath =
        QDir{dataDirectory}.filePath(QStringLiteral("vexa.sqlite3"));

    services::LedgerService service;

    QObject::connect(
        &service,
        &services::LedgerService::loaded,
        &app,
        [&service](
            qint64 accountCount,
            qint64 categoryCount,
            qint64 operationCount)
        {
            qDebug() << "База загружена";
            qDebug() << "Счетов:" << accountCount;
            qDebug() << "Категорий:" << categoryCount;
            qDebug() << "Операций:" << operationCount;

            service.requestTotalBalance(
                QStringLiteral("RUB")
                );
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::totalBalanceReady,
        &app,
        [](qint64 totalMinor, const QString& currencyCode) {
            qDebug() << "Общий итог в минимальных единицах:"
                     << totalMinor
                     << currencyCode;
        },
        Qt::QueuedConnection
        );

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] {
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection
        );

    engine.loadFromModule("UI", "Main");

    qDebug() << "Файл БД:" << databasePath;

    service.open(databasePath);

    return app.exec();
}