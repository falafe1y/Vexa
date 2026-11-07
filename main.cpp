#include "LedgerService.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <memory>

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

    QTemporaryDir testDirectory;

    if (!testDirectory.isValid()) {
        qCritical() << "Не удалось создать временный каталог";
        return 1;
    }

    const QString databasePath = testDirectory.filePath(
        QStringLiteral("commands-test.sqlite3")
        );

    services::LedgerService service;

    struct CommandCheck
    {
        int stage = 0;

        QUuid cashId;
        QUuid dollarId;
        QUuid salaryId;
        QUuid groceriesId;
    };

    const auto commandCheck = std::make_shared<CommandCheck>();

    QObject::connect(
        &service,
        &services::LedgerService::loaded,
        &app,
        [&service](
            qint64 accountCount,
            qint64 categoryCount,
            qint64 operationCount)
        {
            qDebug() << "Начальные количества:"
                     << accountCount
                     << categoryCount
                     << operationCount;

            service.createAccount(
                QStringLiteral("Наличные"),
                core::model::AccountType::Cash,
                QStringLiteral("RUB"),
                100'000
                );
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::commandSucceeded,
        &app,
        [&service, commandCheck](
            const QString& commandName,
            const QUuid& id)
        {
            qDebug() << "Команда выполнена:" << commandName << id;

            switch (commandCheck->stage++) {
            case 0:
                commandCheck->cashId = id;

                service.createAccount(
                    QStringLiteral("Долларовая карта"),
                    core::model::AccountType::DebitCard,
                    QStringLiteral("USD"),
                    10'000
                    );
                break;

            case 1:
                commandCheck->dollarId = id;

                service.createCategory(
                    QStringLiteral("Зарплата"),
                    core::model::CategoryType::Income
                    );
                break;

            case 2:
                commandCheck->salaryId = id;

                service.createCategory(
                    QStringLiteral("Продукты"),
                    core::model::CategoryType::Expense
                    );
                break;

            case 3:
                commandCheck->groceriesId = id;

                service.addIncome(
                    commandCheck->cashId,
                    commandCheck->salaryId,
                    20'000,
                    QDate::currentDate()
                    );
                break;

            case 4:
                service.addExpense(
                    commandCheck->cashId,
                    commandCheck->groceriesId,
                    25'000,
                    QDate::currentDate()
                    );
                break;

            case 5:
                service.transfer(
                    commandCheck->dollarId,
                    commandCheck->cashId,
                    1'000,
                    QDate::currentDate()
                    );
                break;

            case 6:
                service.requestTotalBalance(
                    QStringLiteral("RUB")
                    );
                break;
            }
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::commandFailed,
        &app,
        [](const QString& commandName, const QString& message) {
            qCritical() << "Ошибка команды:"
                        << commandName
                        << message;

            QCoreApplication::exit(1);
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::totalBalanceReady,
        &app,
        [](qint64 totalMinor, const QString& currencyCode) {
            qDebug() << "Общий итог:"
                     << totalMinor
                     << currencyCode;

            if (currencyCode != QStringLiteral("RUB") ||
                totalMinor != 995'000) {
                qCritical() << "Неверный результат проверки";
                QCoreApplication::exit(1);
                return;
            }

            qDebug() << "Проверка команд пройдена";
            QCoreApplication::quit();
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