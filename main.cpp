#include "LedgerInterface.h"
#include "LedgerService.h"
#include "SettingsService.h"
#include "UpdateService.h"
#include "UpdateInterface.h"

#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QFontDatabase>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QVariant>

#include <exception>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    // QCoreApplication::setOrganizationName(QStringLiteral("Vexa"));
    QCoreApplication::setApplicationName(QStringLiteral("Vexa"));
    QCoreApplication::setApplicationVersion(QStringLiteral(VEXA_VERSION));

    // Presentation-only fonts; no legacy services, controllers or JS.
    const QDir editorialFonts(QStringLiteral(":/fonts/editorial"));
    for (const QString& name : editorialFonts.entryList(
             {QStringLiteral("*.ttf")}, QDir::Files)) {
        if (QFontDatabase::addApplicationFont(editorialFonts.filePath(name)) < 0) {
            qCritical() << "Не удалось загрузить шрифт:" << name;
            return 1;
        }
    }

    try {
        const auto directory = QStandardPaths::writableLocation(
            QStandardPaths::AppDataLocation);

        if (directory.isEmpty() || !QDir{}.mkpath(directory)) {
            qCritical() << "Не удалось создать каталог данных";
            return 1;
        }

        const auto filePath = QDir{directory}.filePath(QStringLiteral("vexa.sqlite3"));

        services::LedgerService service;

        // ВРЕМЕННО
        QObject::connect(
            &service,
            &services::LedgerService::loaded,
            &app,
            [](qint64 accounts, qint64 categories, qint64 operations) {
                qDebug() << "БД успешно загружена:"
                         << accounts << "счетов,"
                         << categories << "категорий,"
                         << operations << "операций";
            }
            );

        QObject::connect(
            &service,
            &services::LedgerService::failed,
            &app,
            [](const QString& message) {
                qCritical() << "Ошибка открытия БД:" << message;
            }
            );

        services::SettingsService settings;
        interfaces::LedgerInterface ledgerInterface{service, settings};
        services::UpdateService updateService;
        interfaces::UpdateInterface updateInterface{updateService};

        QQmlApplicationEngine engine;
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
            &app, [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

        engine.rootContext()->setContextProperty(
            QStringLiteral("appVersion"),
            QCoreApplication::applicationVersion()
        );

        engine.setInitialProperties({
            {QStringLiteral("ledger"),
             QVariant::fromValue(static_cast<QObject*>(&ledgerInterface))},
            {QStringLiteral("updates"),
             QVariant::fromValue(static_cast<QObject*>(&updateInterface))}
        });
        engine.loadFromModule("UI", "Main");

        if (engine.rootObjects().isEmpty()) return 1;

        qDebug() << "Файл БД:" << filePath;
        service.open(filePath);
        updateService.checkForUpdates();
        return app.exec();
    } catch (const std::exception& error) {
        qCritical() << "Ошибка запуска:" << error.what();
        return 1;
    }
}
