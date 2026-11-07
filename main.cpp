#include "Account.h"
#include "Category.h"
#include "Currency.h"
#include "Database.h"
#include "Ledger.h"
#include "Money.h"
#include "Operation.h"

#include <QDate>
#include <QDebug>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QTemporaryDir>
#include <QUuid>

#include <exception>
#include <stdexcept>
#include <variant>

using namespace core::model;

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);

    try {
        const auto rub = Currency::fromCode("RUB");
        const auto usd = Currency::fromCode("USD");

        // Проверка сохранения и загрузки данных.
        {
            QTemporaryDir directory;

            if (!directory.isValid()) {
                throw std::runtime_error(
                    "Cannot create temporary database directory"
                    );
            }

            const QString filePath = directory.filePath(
                QStringLiteral("vexa-test.sqlite3")
                );

            const Account originalAccount{
                QUuid::createUuid(),
                QStringLiteral("Наличные"),
                AccountType::Cash,
                Money::fromMinorUnits(100'000, rub)
            };

            Category originalCategory{
                QUuid::createUuid(),
                QStringLiteral("Продукты"),
                CategoryType::Expense
            };

            // Сохраняем данные и закрываем соединение.
            {
                core::db::Database database{filePath};

                database.saveAccount(originalAccount);
                database.saveAccount(originalAccount);

                database.saveCategory(originalCategory);

                originalCategory.archive();
                database.saveCategory(originalCategory);
            }

            // Повторно открываем базу и проверяем данные.
            {
                core::db::Database database{filePath};

                const auto accounts = database.loadAccounts();

                if (accounts.size() != 1) {
                    throw std::runtime_error(
                        "Unexpected account count"
                        );
                }

                const auto& restoredAccount = accounts.front();

                if (restoredAccount.id() != originalAccount.id() ||
                    restoredAccount.name() != originalAccount.name() ||
                    restoredAccount.type() != originalAccount.type() ||
                    restoredAccount.openingBalance() !=
                        originalAccount.openingBalance() ||
                    restoredAccount.isArchived() !=
                        originalAccount.isArchived()) {
                    throw std::runtime_error(
                        "Restored account differs from original"
                        );
                }

                qDebug() << "Счет восстановлен:"
                         << restoredAccount.name()
                         << restoredAccount.openingBalance().minorUnits();

                qDebug() << "Проверка сохранения счета пройдена";

                const auto categories = database.loadCategories();

                if (categories.size() != 1) {
                    throw std::runtime_error(
                        "Unexpected category count"
                        );
                }

                const auto& restoredCategory = categories.front();

                if (restoredCategory.id() != originalCategory.id() ||
                    restoredCategory.name() != originalCategory.name() ||
                    restoredCategory.type() != originalCategory.type() ||
                    restoredCategory.isArchived() !=
                        originalCategory.isArchived()) {
                    throw std::runtime_error(
                        "Restored category differs from original"
                        );
                }

                qDebug() << "Категория восстановлена:"
                         << restoredCategory.name()
                         << "Архив:" << restoredCategory.isArchived();

                qDebug() << "Проверка сохранения категории пройдена";
            }
        }

        // Проверка переводов, расходов, остатков и долга.
        const Account dollarCard{
            QUuid::createUuid(),
            QStringLiteral("Долларовая карта"),
            AccountType::DebitCard,
            Money::fromMinorUnits(10'000, usd)
        };

        const Account cash{
            QUuid::createUuid(),
            QStringLiteral("Наличные"),
            AccountType::Cash,
            Money::fromMinorUnits(0, rub)
        };

        const auto operation = Operation::transfer(
            QUuid::createUuid(),
            QDate::currentDate(),
            dollarCard,
            cash,
            Money::fromMinorUnits(1'000, usd)
            );

        const auto& transfer =
            std::get<Operation::Transfer>(operation.details());

        qDebug() << transfer.sentAmount.minorUnits()
                 << transfer.receivedAmount.minorUnits()
                 << transfer.rate.numerator()
                 << transfer.rate.denominator();

        Ledger ledger;

        ledger.addAccount(dollarCard);
        ledger.addAccount(cash);
        ledger.addOperation(operation);

        qDebug() << ledger.balance(dollarCard.id()).minorUnits()
                 << ledger.balance(cash.id()).minorUnits();

        const Category groceries{
            QUuid::createUuid(),
            QStringLiteral("Продукты"),
            CategoryType::Expense
        };

        ledger.addCategory(groceries);

        ledger.addOperation(Operation::expense(
            QUuid::createUuid(),
            QDate::currentDate(),
            cash,
            groceries,
            Money::fromMinorUnits(25'000, rub)
            ));

        qDebug() << ledger.balance(cash.id()).minorUnits();
        qDebug() << ledger.totalBalance(rub).minorUnits();

        const Account creditCard{
            QUuid::createUuid(),
            QStringLiteral("Кредитка"),
            AccountType::CreditCard,
            Money::fromMinorUnits(0, rub)
        };

        ledger.addAccount(creditCard);

        ledger.addOperation(Operation::expense(
            QUuid::createUuid(),
            QDate::currentDate(),
            creditCard,
            groceries,
            Money::fromMinorUnits(40'000, rub)
            ));

        qDebug() << ledger.balance(creditCard.id()).minorUnits()
                 << ledger.debt(creditCard.id()).minorUnits()
                 << ledger.totalBalance(rub).minorUnits();
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