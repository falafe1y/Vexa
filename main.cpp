#include "LedgerInterface.h"
#include "LedgerService.h"

#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QVariant>

#include <exception>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName(
        QStringLiteral("Vexa")
        );

    QCoreApplication::setApplicationName(
        QStringLiteral("Vexa")
        );

    try {
        const auto directory =
            QStandardPaths::writableLocation(
                QStandardPaths::AppDataLocation
                );

        if (directory.isEmpty()
            || !QDir{}.mkpath(directory)) {
            qCritical() << "Не удалось создать каталог данных";
            return 1;
        }

        const auto filePath = QDir{directory}.filePath(
            QStringLiteral("vexa.sqlite3")
            );

        services::LedgerService service;

        interfaces::LedgerInterface ledgerInterface{
            service,
            QStringLiteral("RUB")
        };

        QQmlApplicationEngine engine;

        QObject::connect(
            &engine,
            &QQmlApplicationEngine::objectCreationFailed,
            &app,
            []() {
                QCoreApplication::exit(-1);
            },
            Qt::QueuedConnection
            );

        engine.setInitialProperties({
            {
                QStringLiteral("ledger"),
                QVariant::fromValue(
                    static_cast<QObject*>(&ledgerInterface)
                    )
            }
        });

        engine.loadFromModule("UI", "Main");

        if (engine.rootObjects().isEmpty()) {
            return 1;
        }

        qDebug() << "Файл БД:" << filePath;

        service.open(filePath);

        return app.exec();
    } catch (const std::exception& error) {
        qCritical() << "Ошибка запуска:" << error.what();
        return 1;
    }
}