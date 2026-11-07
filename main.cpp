#include "Account.h"
#include "Category.h"
#include "Currency.h"
#include "Database.h"
#include "ExchangeRate.h"
#include "Ledger.h"
#include "Money.h"
#include "Operation.h"

#include <QDate>
#include <QDebug>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QTemporaryDir>
#include <QUuid>

#include <cstddef>
#include <exception>
#include <stdexcept>
#include <variant>
#include <vector>

using namespace core::model;

namespace {

void check(bool condition, const char* message)
{
    if (!condition) {
        throw std::runtime_error(message);
    }
}

} // namespace

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);

    try {
        QTemporaryDir directory;

        check(
            directory.isValid(),
            "Cannot create temporary database directory"
            );

        const QString filePath = directory.filePath(
            QStringLiteral("vexa-test.sqlite3")
            );

        const auto rub = Currency::fromCode("RUB");
        const auto usd = Currency::fromCode("USD");
        const auto date = QDate::currentDate();

        const Account dollarCard{
            QUuid::createUuid(),
            QStringLiteral("Долларовая карта"),
            AccountType::DebitCard,
            Money::fromMinorUnits(10'000, usd)
        };

        Account cash{
            QUuid::createUuid(),
            QStringLiteral("Наличные"),
            AccountType::Cash,
            Money::fromMinorUnits(0, rub)
        };

        const Account creditCard{
            QUuid::createUuid(),
            QStringLiteral("Кредитка"),
            AccountType::CreditCard,
            Money::fromMinorUnits(0, rub)
        };

        Category groceries{
            QUuid::createUuid(),
            QStringLiteral("Продукты"),
            CategoryType::Expense
        };

        const Category salary{
            QUuid::createUuid(),
            QStringLiteral("Зарплата"),
            CategoryType::Income
        };

        const auto historicalRate =
            ExchangeRate::customRatio(usd, rub, 85, 1);

        const std::vector<Operation> originalOperations{
            Operation(
                QUuid::createUuid(),
                date,
                Operation::Transfer{
                    dollarCard.id(),
                    cash.id(),
                    Money::fromMinorUnits(1'000, usd),
                    Money::fromMinorUnits(85'000, rub),
                    historicalRate
                }
                ),

            Operation::expense(
                QUuid::createUuid(),
                date,
                cash,
                groceries,
                Money::fromMinorUnits(25'000, rub)
                ),

            Operation::income(
                QUuid::createUuid(),
                date,
                cash,
                salary,
                Money::fromMinorUnits(20'000, rub)
                ),

            Operation::expense(
                QUuid::createUuid(),
                date,
                creditCard,
                groceries,
                Money::fromMinorUnits(40'000, rub)
                )
        };

        // История должна загружаться и после архивации.
        cash.archive();
        groceries.archive();

        const std::vector<Account> originalAccounts{
            dollarCard,
            cash,
            creditCard
        };

        const std::vector<Category> originalCategories{
            groceries,
            salary
        };

        {
            core::db::Database database{filePath};

            for (const auto& account : originalAccounts) {
                database.saveAccount(account);
            }

            for (const auto& category : originalCategories) {
                database.saveCategory(category);
            }

            for (const auto& operation : originalOperations) {
                database.saveOperation(operation);
            }

            // Повторная запись не должна создавать дубликаты.
            database.saveAccount(cash);
            database.saveCategory(groceries);
            database.saveOperation(originalOperations.front());

            // Неиспользуемые записи можно удалить.
            const Account unusedAccount{
                QUuid::createUuid(),
                QStringLiteral("Временный счет"),
                AccountType::Cash,
                Money::fromMinorUnits(0, rub)
            };

            const Category unusedCategory{
                QUuid::createUuid(),
                QStringLiteral("Временная категория"),
                CategoryType::Income
            };

            database.saveAccount(unusedAccount);
            database.saveCategory(unusedCategory);

            database.removeAccount(unusedAccount.id());
            database.removeCategory(unusedCategory.id());

            const auto temporaryOperation = Operation::income(
                QUuid::createUuid(),
                date,
                dollarCard,
                salary,
                Money::fromMinorUnits(1, usd)
                );

            database.saveOperation(temporaryOperation);
            database.removeOperation(temporaryOperation.id());

            // Используемые записи удалить нельзя.
            bool accountProtected = false;

            try {
                database.removeAccount(cash.id());
            } catch (const std::runtime_error&) {
                accountProtected = true;
            }

            check(
                accountProtected,
                "Used account was not protected from deletion"
                );

            bool categoryProtected = false;

            try {
                database.removeCategory(groceries.id());
            } catch (const std::runtime_error&) {
                categoryProtected = true;
            }

            check(
                categoryProtected,
                "Used category was not protected from deletion"
                );
        }

        // Первое соединение закрыто. Читаем данные заново.
        {
            core::db::Database database{filePath};

            const auto accounts = database.loadAccounts();
            const auto categories = database.loadCategories();
            const auto operations = database.loadOperations();

            check(accounts.size() == 3, "Unexpected account count");
            check(categories.size() == 2, "Unexpected category count");
            check(operations.size() == 4, "Unexpected operation count");

            for (std::size_t i = 0; i < operations.size(); ++i) {
                check(
                    operations[i].id() == originalOperations[i].id(),
                    "Operation ID or order changed"
                    );

                check(
                    operations[i].date() == originalOperations[i].date(),
                    "Operation date changed"
                    );

                check(
                    operations[i].details().index() ==
                        originalOperations[i].details().index(),
                    "Operation type changed"
                    );
            }

            const auto& transfer =
                std::get<Operation::Transfer>(
                    operations.front().details()
                    );

            check(
                transfer.sentAmount ==
                    Money::fromMinorUnits(1'000, usd),
                "Stored sent amount changed"
                );

            check(
                transfer.receivedAmount ==
                    Money::fromMinorUnits(85'000, rub),
                "Stored received amount changed"
                );

            check(
                transfer.rate.numerator() == 85 &&
                    transfer.rate.denominator() == 1,
                "Historical exchange rate changed"
                );

            auto ledger = Ledger::fromStoredData(
                accounts,
                categories,
                operations
                );

            check(
                ledger.balance(dollarCard.id()).minorUnits() == 9'000,
                "Incorrect dollar account balance"
                );

            check(
                ledger.balance(cash.id()).minorUnits() == 80'000,
                "Incorrect cash balance"
                );

            check(
                ledger.balance(creditCard.id()).minorUnits() == -40'000,
                "Incorrect credit card balance"
                );

            check(
                ledger.debt(creditCard.id()).minorUnits() == 40'000,
                "Incorrect debt"
                );

            // Общая оценка использует текущий фиксированный курс.
            const auto expectedTotal =
                ExchangeRate::fixed(usd, rub).convert(
                    Money::fromMinorUnits(9'000, usd)
                    ) + Money::fromMinorUnits(40'000, rub);

            check(
                ledger.totalBalance(rub) == expectedTotal,
                "Incorrect total balance"
                );

            // Загруженная история разрешена, новая операция
            // по архивному счету должна быть отклонена.
            bool archivedAccountRejected = false;

            try {
                ledger.addOperation(Operation(
                    QUuid::createUuid(),
                    date,
                    Operation::Income{
                        cash.id(),
                        salary.id(),
                        Money::fromMinorUnits(100, rub)
                    }
                    ));
            } catch (const std::invalid_argument&) {
                archivedAccountRejected = true;
            }

            check(
                archivedAccountRejected,
                "Archived account accepted a new operation"
                );

            bool archivedCategoryRejected = false;

            try {
                ledger.addOperation(Operation(
                    QUuid::createUuid(),
                    date,
                    Operation::Expense{
                        creditCard.id(),
                        groceries.id(),
                        Money::fromMinorUnits(100, rub)
                    }
                    ));
            } catch (const std::invalid_argument&) {
                archivedCategoryRejected = true;
            }

            check(
                archivedCategoryRejected,
                "Archived category accepted a new operation"
                );

            check(
                ledger.balance(cash.id()).minorUnits() == 80'000 &&
                    ledger.balance(creditCard.id()).minorUnits() == -40'000,
                "Rejected operations changed balances"
                );

            qDebug() << "Загружено счетов:" << accounts.size();
            qDebug() << "Загружено категорий:" << categories.size();
            qDebug() << "Загружено операций:" << operations.size();

            qDebug() << "Сохраненный курс:"
                     << transfer.rate.numerator()
                     << transfer.rate.denominator();

            qDebug() << "Остатки:"
                     << ledger.balance(dollarCard.id()).minorUnits()
                     << ledger.balance(cash.id()).minorUnits()
                     << ledger.balance(creditCard.id()).minorUnits();

            qDebug() << "Долг:"
                     << ledger.debt(creditCard.id()).minorUnits();

            qDebug() << "Общий итог:"
                     << ledger.totalBalance(rub).minorUnits();

            qDebug() << "Проверка БД пройдена";
        }
    } catch (const std::exception& error) {
        qCritical() << "Ошибка проверки:" << error.what();
        return 1;
    }

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

    return app.exec();
}