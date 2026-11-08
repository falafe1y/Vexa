#include "AccountService.h"
#include "CategoryService.h"
#include "LedgerService.h"
#include "OperationService.h"
#include "Currency.h"
#include "Database.h"
#include "Ledger.h"
#include "Money.h"
#include "Operation.h"
#include "ArchiveService.h"
#include "ExchangeRate.h"
#include "LedgerReadService.h"

#include <vector>
#include <QCoreApplication>
#include <QDate>
#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <exception>
#include <limits>
#include <stdexcept>

namespace {

void checkHistory()
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
        "Cannot create history test directory"
        );

    const QString filePath = directory.filePath(
        QStringLiteral("history-test.sqlite3")
        );

    const auto rub = Currency::fromCode("RUB");
    const auto usd = Currency::fromCode("USD");

    std::vector<QUuid> expectedIds;

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

        const QUuid cashId = accounts.create(
            QStringLiteral("Наличные"),
            AccountType::Cash,
            QStringLiteral("RUB"),
            100'000
            );

        const QUuid dollarId = accounts.create(
            QStringLiteral("Долларовая карта"),
            AccountType::DebitCard,
            QStringLiteral("USD"),
            10'000
            );

        const QUuid salaryId = categories.create(
            QStringLiteral("Зарплата"),
            CategoryType::Income
            );

        const QUuid groceriesId = categories.create(
            QStringLiteral("Продукты"),
            CategoryType::Expense
            );

        const QUuid incomeId = operations.income(
            cashId,
            salaryId,
            10'000,
            QDate{2026, 11, 1}
            );

        const QUuid firstExpenseId = operations.expense(
            cashId,
            groceriesId,
            5'000,
            QDate{2026, 11, 3}
            );

        // Исторический перевод по курсу 85, а не текущему 90.
        const auto rate =
            ExchangeRate::customRatio(usd, rub, 85, 1);

        const Operation transfer{
            QUuid::createUuid(),
            QDate{2026, 11, 2},
            Operation::Transfer{
                dollarId,
                cashId,
                Money::fromMinorUnits(1'000, usd),
                Money::fromMinorUnits(85'000, rub),
                rate
            }
        };

        {
            auto candidate = ledger;
            candidate.addOperation(transfer);

            database.saveOperation(transfer);

            ledger.swap(candidate);
        }

        const QUuid lastExpenseId = operations.expense(
            cashId,
            groceriesId,
            2'000,
            QDate{2026, 11, 3}
            );

        expectedIds = {
            lastExpenseId,
            firstExpenseId,
            transfer.id(),
            incomeId
        };

        using Result = services::ArchiveService::Result;

        require(
            archive.removeAccount(cashId) == Result::Archived &&
                archive.removeAccount(dollarId) == Result::Archived &&
                archive.removeCategory(salaryId) == Result::Archived &&
                archive.removeCategory(groceriesId) == Result::Archived,
            "Test entities were not archived"
            );

        services::LedgerReadService reader{ledger};

        const auto first = reader.operations(0, 3);
        const auto second = reader.operations(first.nextOffset, 3);

        require(
            first.items.size() == 3 &&
                first.offset == 0 &&
                first.nextOffset == 3 &&
                first.totalCount == 4 &&
                first.hasMore,
            "Incorrect first history page"
            );

        require(
            second.items.size() == 1 &&
                second.offset == 3 &&
                second.nextOffset == 4 &&
                second.totalCount == 4 &&
                !second.hasMore,
            "Incorrect final history page"
            );

        std::vector<QUuid> actualIds;

        for (const auto& item : first.items) {
            actualIds.push_back(item.id);
        }

        for (const auto& item : second.items) {
            actualIds.push_back(item.id);
        }

        require(
            actualIds == expectedIds,
            "Incorrect history order, missing or duplicate records"
            );

        const auto& expense = first.items[0];

        require(
            expense.type == services::OperationType::Expense &&
                expense.amountMinor == 2'000 &&
                expense.accountName == QStringLiteral("Наличные") &&
                expense.categoryName == QStringLiteral("Продукты"),
            "Incorrect expense data"
            );

        const auto& transferData = first.items[2];

        require(
            transferData.type == services::OperationType::Transfer &&
                transferData.accountId == dollarId &&
                transferData.toAccountId == cashId &&
                transferData.accountName ==
                    QStringLiteral("Долларовая карта") &&
                transferData.toAccountName ==
                    QStringLiteral("Наличные") &&
                transferData.amountMinor == 1'000 &&
                transferData.currencyCode == QStringLiteral("USD") &&
                transferData.receivedAmountMinor == 85'000 &&
                transferData.receivedCurrencyCode ==
                    QStringLiteral("RUB") &&
                transferData.categoryId.isNull(),
            "Incorrect stored transfer data"
            );

        const auto& income = second.items[0];

        require(
            income.type == services::OperationType::Income &&
                income.amountMinor == 10'000 &&
                income.categoryName == QStringLiteral("Зарплата"),
            "Incorrect income data"
            );

        const auto end = reader.operations(
            std::numeric_limits<qint64>::max(),
            3
            );

        require(
            end.items.empty() &&
                end.offset == 4 &&
                end.nextOffset == 4 &&
                !end.hasMore,
            "Incorrect page beyond the end of history"
            );

        bool invalidOffsetRejected = false;

        try {
            (void)reader.operations(-1, 3);
        } catch (const std::invalid_argument&) {
            invalidOffsetRejected = true;
        }

        require(
            invalidOffsetRejected,
            "Negative history offset was accepted"
            );

        bool invalidLimitRejected = false;

        try {
            (void)reader.operations(0, 0);
        } catch (const std::invalid_argument&) {
            invalidLimitRejected = true;
        }

        require(
            invalidLimitRejected,
            "Zero history limit was accepted"
            );

        Ledger emptyLedger;

        const auto emptyPage =
            services::LedgerReadService{emptyLedger}
                .operations(0, 3);

        require(
            emptyPage.items.empty() &&
                emptyPage.totalCount == 0 &&
                emptyPage.nextOffset == 0 &&
                !emptyPage.hasMore,
            "Incorrect empty history page"
            );

        qDebug() << "Первая порция:" << first.items.size();
        qDebug() << "Вторая порция:" << second.items.size();
        qDebug() << "История архивных счетов и категорий доступна";
        qDebug() << "Сохраненные суммы перевода не изменились";
    }

    {
        core::db::Database database{filePath};

        const auto ledger = Ledger::fromStoredData(
            database.loadAccounts(),
            database.loadCategories(),
            database.loadOperations()
            );

        const auto page =
            services::LedgerReadService{ledger}
                .operations(0, 10);

        std::vector<QUuid> actualIds;

        for (const auto& item : page.items) {
            actualIds.push_back(item.id);
        }

        require(
            actualIds == expectedIds,
            "History order changed after reopening database"
            );

        require(
            page.items[2].receivedAmountMinor == 85'000,
            "Historical transfer amount changed after reopening"
            );

        qDebug() << "Порядок сохранен после повторного открытия БД";
    }

    qDebug() << "Проверка истории пройдена";
}

void checkOperationRemoval()
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
        "Cannot create operation removal test directory"
        );

    const QString filePath = directory.filePath(
        QStringLiteral("operation-removal-test.sqlite3")
        );

    const auto rub = Currency::fromCode("RUB");

    QUuid cashId;
    QUuid dollarId;
    QUuid creditId;

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

        creditId = accounts.create(
            QStringLiteral("Кредитка"),
            AccountType::CreditCard,
            QStringLiteral("RUB"),
            0,
            9'000'000
            );

        const QUuid salaryId = categories.create(
            QStringLiteral("Зарплата"),
            CategoryType::Income
            );

        const QUuid groceriesId = categories.create(
            QStringLiteral("Продукты"),
            CategoryType::Expense
            );

        const auto date = QDate::currentDate();

        const QUuid incomeId = operations.income(
            cashId,
            salaryId,
            20'000,
            date
            );

        const QUuid expenseId = operations.expense(
            cashId,
            groceriesId,
            25'000,
            date
            );

        const QUuid transferId = operations.transfer(
            dollarId,
            cashId,
            1'000,
            date
            );

        const QUuid creditExpenseId = operations.expense(
            creditId,
            groceriesId,
            40'000,
            date
            );

        require(
            ledger.operationCount() == 4,
            "Unexpected initial operation count"
            );

        // Удаление перевода должно пересчитать оба счета.
        (void)operations.remove(transferId);

        require(
            ledger.balance(dollarId).minorUnits() == 10'000 &&
                ledger.balance(cashId).minorUnits() == 95'000 &&
                ledger.balance(creditId).minorUnits() == -40'000,
            "Incorrect balances after transfer removal"
            );

        const auto remaining = database.loadOperations();

        require(
            remaining.size() == 3,
            "Transfer was not removed from database"
            );

        require(
            remaining[0].id() == incomeId &&
                remaining[1].id() == expenseId &&
                remaining[2].id() == creditExpenseId,
            "Remaining operation IDs or order changed"
            );

        qDebug() << "Перевод удален, оба остатка пересчитаны";

        // Удаляем доход.
        (void)operations.remove(incomeId);

        require(
            ledger.balance(cashId).minorUnits() == 75'000,
            "Incorrect balance after income removal"
            );

        // Удаляем расход.
        (void)operations.remove(expenseId);

        require(
            ledger.balance(cashId).minorUnits() == 100'000,
            "Incorrect balance after expense removal"
            );

        // Удаляем расход кредитки.
        (void)operations.remove(creditExpenseId);

        require(
            ledger.balance(creditId).minorUnits() == 0 &&
                ledger.debt(creditId).minorUnits() == 0 &&
                ledger.availableBalance(creditId).minorUnits() ==
                    9'000'000,
            "Incorrect credit card values after expense removal"
            );

        bool unknownOperationRejected = false;

        try {
            (void)operations.remove(QUuid::createUuid());
        } catch (const std::invalid_argument&) {
            unknownOperationRejected = true;
        }

        require(
            unknownOperationRejected,
            "Unknown operation removal was not rejected"
            );

        require(
            ledger.operationCount() == 0 &&
                database.loadOperations().empty(),
            "Unexpected operations after removal"
            );
    }

    // Проверяем сохранение результата после закрытия соединения.
    {
        core::db::Database database{filePath};

        auto ledger = Ledger::fromStoredData(
            database.loadAccounts(),
            database.loadCategories(),
            database.loadOperations()
            );

        require(
            ledger.accountCount() == 3 &&
                ledger.categoryCount() == 2 &&
                ledger.operationCount() == 0,
            "Unexpected record counts after reopening database"
            );

        require(
            ledger.balance(cashId).minorUnits() == 100'000 &&
                ledger.balance(dollarId).minorUnits() == 10'000 &&
                ledger.balance(creditId).minorUnits() == 0,
            "Balances changed after reopening database"
            );

        require(
            ledger.debt(creditId).minorUnits() == 0 &&
                ledger.availableBalance(creditId).minorUnits() ==
                    9'000'000,
            "Credit card values changed after reopening database"
            );

        qDebug() << "Удаление сохранено после повторного открытия БД";
    }

    // Удаление не должно оставлять журнал с некорректными расчетами.
    {
        Ledger ledger;

        const Account account{
            QUuid::createUuid(),
            QStringLiteral("Проверка переполнения"),
            AccountType::Cash,
            Money::fromMinorUnits(
                std::numeric_limits<qint64>::max(),
                rub
                )
        };

        const Category expenseCategory{
            QUuid::createUuid(),
            QStringLiteral("Расход"),
            CategoryType::Expense
        };

        const Category incomeCategory{
            QUuid::createUuid(),
            QStringLiteral("Доход"),
            CategoryType::Income
        };

        ledger.addAccount(account);
        ledger.addCategory(expenseCategory);
        ledger.addCategory(incomeCategory);

        const auto expense = Operation::expense(
            QUuid::createUuid(),
            QDate::currentDate(),
            account,
            expenseCategory,
            Money::fromMinorUnits(1, rub)
            );

        ledger.addOperation(expense);

        ledger.addOperation(Operation::income(
            QUuid::createUuid(),
            QDate::currentDate(),
            account,
            incomeCategory,
            Money::fromMinorUnits(1, rub)
            ));

        bool rejected = false;

        try {
            ledger.removeOperation(expense.id());
        } catch (const std::overflow_error&) {
            rejected = true;
        }

        require(
            rejected &&
                ledger.operationCount() == 2 &&
                ledger.balance(account.id()).minorUnits() ==
                    std::numeric_limits<qint64>::max(),
            "Failed removal changed the ledger"
            );

        qDebug() << "Ошибка расчета не изменяет исходный журнал";
    }

    qDebug() << "Проверка удаления операций пройдена";
}

} // namespace

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName(
        QStringLiteral("Vexa")
        );

    QCoreApplication::setApplicationName(
        QStringLiteral("Vexa")
        );

    if (app.arguments().contains(
            QStringLiteral("--check-operation-removal"))) {
        try {
            checkOperationRemoval();
            return 0;
        } catch (const std::exception& error) {
            qCritical() << "Ошибка проверки:" << error.what();
            return 1;
        }
    }

    if (app.arguments().contains(
            QStringLiteral("--check-history"))) {
        try {
            checkHistory();
            return 0;
        } catch (const std::exception& error) {
            qCritical() << "Ошибка проверки:" << error.what();
            return 1;
        }
    }

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
        QDir{dataDirectory}.filePath(
            QStringLiteral("vexa.sqlite3")
            );

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
            service.requestAccounts();
            service.requestCategories();
            service.requestTotalBalance(QStringLiteral("RUB"));
            service.requestOperations(0, 50);
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

    QObject::connect(
        &service,
        &services::LedgerService::commandSucceeded,
        &app,
        [](const QString& commandName, const QUuid& id) {
            qDebug() << "Команда выполнена:"
                     << commandName
                     << id;
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::commandFailed,
        &app,
        [](const QString& commandName, const QString& message) {
            qWarning() << "Ошибка команды:"
                       << commandName
                       << message;
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::failed,
        &app,
        [](const QString& message) {
            qCritical() << "Ошибка сервиса:" << message;
            QCoreApplication::exit(1);
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

    QObject::connect(
        &service,
        &services::LedgerService::accountsReady,
        &app,
        [](const services::AccountList& accounts) {
            qDebug() << "Получено счетов:" << accounts.size();

            for (const auto& account : accounts) {
                qDebug() << "Счет:" << account.name
                         << "Валюта:" << account.currencyCode
                         << "Остаток:" << account.balanceMinor
                         << "Лимит:" << account.creditLimitMinor
                         << "Долг:" << account.debtMinor
                         << "Доступно:" << account.availableBalanceMinor;
            }
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::categoriesReady,
        &app,
        [](const services::CategoryList& categories) {
            qDebug() << "Получено категорий:" << categories.size();

            for (const auto& category : categories) {
                qDebug() << "Категория:" << category.name
                         << "Тип:" << static_cast<int>(category.type);
            }
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::requestFailed,
        &app,
        [](const QString& requestName, const QString& message) {
            qWarning() << "Ошибка получения данных:"
                       << requestName
                       << message;
        },
        Qt::QueuedConnection
        );

    QObject::connect(
        &service,
        &services::LedgerService::operationsReady,
        &app,
        [&service](const services::OperationPage& page) {
            if (page.resetRequired) {
                qDebug() << "Журнал изменился, история начата заново";
            }

            qDebug() << "История:"
                     << "смещение" << page.offset
                     << "получено" << page.items.size()
                     << "всего" << page.totalCount;

            for (const auto& operation : page.items) {
                qDebug() << operation.date.toString(Qt::ISODate)
                << "Тип:" << static_cast<int>(operation.type)
                << "Счет:" << operation.accountName
                << "Сумма:" << operation.amountMinor
                << operation.currencyCode
                << "Категория:" << operation.categoryName;

                if (operation.type ==
                    services::OperationType::Transfer) {
                    qDebug() << "Получатель:"
                             << operation.toAccountName
                             << "Получено:"
                             << operation.receivedAmountMinor
                             << operation.receivedCurrencyCode;
                }
            }

            // Для консольной проверки последовательно читаем все порции.
            if (page.hasMore) {
                service.requestOperations(
                    page.nextOffset,
                    page.limit,
                    page.version
                    );
            }
        },
        Qt::QueuedConnection
        );

    service.open(databasePath);

    return app.exec();
}