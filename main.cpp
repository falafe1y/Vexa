#include "LedgerService.h"
#include "AccountService.h"
#include "ArchiveService.h"
#include "CategoryService.h"
#include "OperationService.h"
#include "Currency.h"
#include "Database.h"
#include "Ledger.h"
#include "Money.h"

#include <QDate>
#include <QTemporaryDir>
#include <exception>
#include <stdexcept>
#include <vector>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <memory>

void checkCreditCards()
{
    using namespace core::model;

    const auto require = [](bool condition, const char* message) {
        if (!condition) {
            throw std::runtime_error(message);
        }
    };

    const auto rub = Currency::fromCode("RUB");
    const auto usd = Currency::fromCode("USD");

    const auto expectInvalidLimit = [&](
                                        AccountType type,
                                        Money limit)
    {
        bool rejected = false;

        try {
            (void)Account{
                QUuid::createUuid(),
                QStringLiteral("Проверка"),
                type,
                Money::fromMinorUnits(0, rub),
                limit
            };
        } catch (const std::invalid_argument&) {
            rejected = true;
        }

        require(rejected, "Invalid credit limit was accepted");
    };

    expectInvalidLimit(
        AccountType::CreditCard,
        Money::fromMinorUnits(-1, rub)
        );

    expectInvalidLimit(
        AccountType::CreditCard,
        Money::fromMinorUnits(1, usd)
        );

    expectInvalidLimit(
        AccountType::Cash,
        Money::fromMinorUnits(1, rub)
        );

    expectInvalidLimit(
        AccountType::DebitCard,
        Money::fromMinorUnits(1, rub)
        );

    QTemporaryDir directory;

    require(
        directory.isValid(),
        "Cannot create credit card test directory"
        );

    const QString filePath = directory.filePath(
        QStringLiteral("credit-card-test.sqlite3")
        );

    QUuid creditId;
    QUuid cashId;

    {
        core::db::Database database{filePath};

        auto ledger = Ledger::fromStoredData(
            database.loadAccounts(),
            database.loadCategories(),
            database.loadOperations()
            );

        services::AccountService accounts{database, ledger};
        services::OperationService operations{database, ledger};

        creditId = accounts.create(
            QStringLiteral("Кредитка"),
            AccountType::CreditCard,
            QStringLiteral("RUB"),
            -6'000'000,
            9'000'000
            );

        require(
            ledger.balance(creditId).minorUnits() == -6'000'000 &&
                ledger.debt(creditId).minorUnits() == 6'000'000 &&
                ledger.availableBalance(creditId).minorUnits() ==
                    3'000'000,
            "Incorrect initial credit card values"
            );

        cashId = accounts.create(
            QStringLiteral("Наличные"),
            AccountType::Cash,
            QStringLiteral("RUB"),
            2'000'000
            );

        // Погашаем 10 000 рублей переводом с наличных.
        (void)operations.transfer(
            cashId,
            creditId,
            1'000'000,
            QDate::currentDate()
            );

        require(
            ledger.debt(creditId).minorUnits() == 5'000'000 &&
                ledger.availableBalance(creditId).minorUnits() ==
                    4'000'000,
            "Incorrect credit card values after repayment"
            );
    }

    {
        core::db::Database database{filePath};

        auto ledger = Ledger::fromStoredData(
            database.loadAccounts(),
            database.loadCategories(),
            database.loadOperations()
            );

        require(
            ledger.account(creditId).creditLimit().minorUnits() ==
                9'000'000,
            "Credit limit was not saved"
            );

        require(
            ledger.account(cashId).creditLimit().minorUnits() == 0,
            "Cash account has a credit limit"
            );

        require(
            ledger.balance(creditId).minorUnits() == -5'000'000 &&
                ledger.debt(creditId).minorUnits() == 5'000'000 &&
                ledger.availableBalance(creditId).minorUnits() ==
                    4'000'000,
            "Credit card values changed after reopening database"
            );

        require(
            ledger.balance(cashId).minorUnits() == 1'000'000 &&
                ledger.totalBalance(rub).minorUnits() == -4'000'000,
            "Credit limit was incorrectly included in total balance"
            );

        qDebug() << "Лимит:"
                 << ledger.account(creditId).creditLimit().minorUnits();

        qDebug() << "Долг:"
                 << ledger.debt(creditId).minorUnits();

        qDebug() << "Доступно:"
                 << ledger.availableBalance(creditId).minorUnits();

        qDebug() << "Проверка кредитки пройдена";
    }
}

void checkArchiving()
{
    using namespace core::model;

    const auto require = [](bool condition, const char* message) {
        if (!condition) {
            throw std::runtime_error(message);
        }
    };

    QTemporaryDir directory;

    require(
        directory.isValid(),
        "Cannot create archive test directory"
        );

    const QString filePath = directory.filePath(
        QStringLiteral("archive-test.sqlite3")
        );

    const auto rub = Currency::fromCode("RUB");

    QUuid cashId;
    QUuid dollarId;
    QUuid salaryId;
    QUuid groceriesId;

    std::vector<QUuid> operationIds;

    qint64 totalBefore = 0;
    qint64 cashBefore = 0;
    qint64 dollarsBefore = 0;

    {
        core::db::Database database{filePath};

        auto ledger = Ledger::fromStoredData(
            database.loadAccounts(),
            database.loadCategories(),
            database.loadOperations()
            );

        services::AccountService accounts{database, ledger};
        services::CategoryService categories{database, ledger};
        services::OperationService operations{database, ledger};
        services::ArchiveService archive{database, ledger};

        cashId = accounts.create(
            QStringLiteral("Наличные"),
            AccountType::Cash,
            QStringLiteral("RUB"),
            100'000
            );

        dollarId = accounts.create(
            QStringLiteral("Долларовая карта"),
            AccountType::DebitCard,
            QStringLiteral("USD"),
            10'000
            );

        const QUuid unusedAccountId = accounts.create(
            QStringLiteral("Неиспользуемый счет"),
            AccountType::Cash,
            QStringLiteral("RUB"),
            0
            );

        salaryId = categories.create(
            QStringLiteral("Зарплата"),
            CategoryType::Income
            );

        groceriesId = categories.create(
            QStringLiteral("Продукты"),
            CategoryType::Expense
            );

        const QUuid unusedCategoryId = categories.create(
            QStringLiteral("Неиспользуемая категория"),
            CategoryType::Expense
            );

        const auto date = QDate::currentDate();

        operationIds.push_back(operations.income(
            cashId,
            salaryId,
            20'000,
            date
            ));

        operationIds.push_back(operations.expense(
            cashId,
            groceriesId,
            25'000,
            date
            ));

        operationIds.push_back(operations.transfer(
            dollarId,
            cashId,
            1'000,
            date
            ));

        totalBefore = ledger.totalBalance(rub).minorUnits();
        cashBefore = ledger.balance(cashId).minorUnits();
        dollarsBefore = ledger.balance(dollarId).minorUnits();

        using Result = services::ArchiveService::Result;

        // Проверяем оба счета перевода.
        require(
            archive.removeAccount(dollarId) == Result::Archived,
            "Transfer sender must be archived"
            );

        require(
            archive.removeAccount(cashId) == Result::Archived,
            "Transfer recipient must be archived"
            );

        require(
            archive.removeCategory(salaryId) == Result::Archived,
            "Used income category must be archived"
            );

        require(
            archive.removeCategory(groceriesId) == Result::Archived,
            "Used expense category must be archived"
            );

        require(
            archive.removeAccount(unusedAccountId) == Result::Deleted,
            "Unused account must be deleted"
            );

        require(
            archive.removeCategory(unusedCategoryId) == Result::Deleted,
            "Unused category must be deleted"
            );

        require(
            ledger.accountCount() == 2 &&
                ledger.categoryCount() == 2 &&
                ledger.operationCount() == 3,
            "Archiving changed unexpected records"
            );

        require(
            ledger.totalBalance(rub).minorUnits() == totalBefore &&
                ledger.balance(cashId).minorUnits() == cashBefore &&
                ledger.balance(dollarId).minorUnits() == dollarsBefore,
            "Archiving changed balances"
            );
    }

    // Соединение закрыто. Проверяем сохраненные изменения.
    {
        core::db::Database database{filePath};

        const auto storedOperations = database.loadOperations();

        auto ledger = Ledger::fromStoredData(
            database.loadAccounts(),
            database.loadCategories(),
            storedOperations
            );

        require(
            ledger.accountCount() == 2 &&
                ledger.categoryCount() == 2 &&
                ledger.operationCount() == 3,
            "Unexpected record counts after reopening database"
            );

        require(
            ledger.account(cashId).isArchived() &&
                ledger.account(dollarId).isArchived(),
            "Account archive flags were not saved"
            );

        require(
            ledger.category(salaryId).isArchived() &&
                ledger.category(groceriesId).isArchived(),
            "Category archive flags were not saved"
            );

        for (std::size_t i = 0; i < operationIds.size(); ++i) {
            require(
                storedOperations[i].id() == operationIds[i],
                "History changed after archiving"
                );
        }

        require(
            ledger.totalBalance(rub).minorUnits() == totalBefore &&
                ledger.balance(cashId).minorUnits() == cashBefore &&
                ledger.balance(dollarId).minorUnits() == dollarsBefore,
            "Balances changed after reopening database"
            );

        services::OperationService operations{database, ledger};

        bool rejected = false;

        try {
            (void)operations.expense(
                cashId,
                groceriesId,
                100,
                QDate::currentDate()
                );
        } catch (const std::invalid_argument&) {
            rejected = true;
        }

        require(
            rejected,
            "Archived entities accepted a new operation"
            );

        require(
            ledger.operationCount() == 3 &&
                database.loadOperations().size() == 3,
            "Rejected operation changed history"
            );

        qDebug() << "Используемые счета и категории архивированы";
        qDebug() << "Неиспользуемые счета и категории удалены";
        qDebug() << "История и остатки сохранены после открытия БД";
        qDebug() << "Проверка архивирования пройдена";
    }
}

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

    try {
        checkArchiving();
    } catch (const std::exception& error) {
        qCritical() << "Ошибка проверки архивирования:"
                    << error.what();

        return 1;
    }

    try {
        checkArchiving();
        checkCreditCards();
    } catch (const std::exception& error) {
        qCritical() << "Ошибка проверки:" << error.what();
        return 1;
    }

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