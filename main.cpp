#include "Account.h"
#include "Category.h"
#include "Operation.h"
#include "Ledger.h"
#include "Database.h"

#include <QDebug>
#include <QDir>
#include <exception>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QTemporaryDir>
#include <stdexcept>

using namespace core::model;

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    try {
        QTemporaryDir directory;

        if (!directory.isValid()) {
            throw std::runtime_error(
                "Cannot create temporary database directory"
                );
        }

        const QString filePath =
            directory.filePath(QStringLiteral("accounts-test.sqlite3"));

        const auto rub = Currency::fromCode("RUB");

        const Account original{
            QUuid::createUuid(),
            QStringLiteral("Наличные"),
            AccountType::Cash,
            Money::fromMinorUnits(100'000, rub)
        };

        {
            core::db::Database database{filePath};

            database.saveAccount(original);

            // Повторное сохранение не должно создавать второй счет.
            database.saveAccount(original);
        }

        // Первое соединение уже закрыто. Открываем файл заново.
        {
            core::db::Database database{filePath};

            const auto accounts = database.loadAccounts();

            if (accounts.size() != 1) {
                throw std::runtime_error("Unexpected account count");
            }

            const auto& restored = accounts.front();

            if (restored.id() != original.id() ||
                restored.name() != original.name() ||
                restored.type() != original.type() ||
                restored.openingBalance() != original.openingBalance() ||
                restored.isArchived() != original.isArchived()) {
                throw std::runtime_error(
                    "Restored account differs from original"
                    );
            }

            qDebug() << "Счет восстановлен:"
                     << restored.name()
                     << restored.openingBalance().minorUnits();

            qDebug() << "Проверка сохранения пройдена";
        }
    } catch (const std::exception& error) {
        qCritical() << "Ошибка БД:" << error.what();
        return 1;
    }

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("UI", "Main");

    const auto usd = Currency::fromCode("USD");
    const auto rub = Currency::fromCode("RUB");

    const Account dollarCard{
        QUuid::createUuid(),
        QStringLiteral("Долларовая карта"),
        AccountType::DebitCard,
        Money::fromMinorUnits(10000, usd)
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
        Money::fromMinorUnits(1000, usd)
        );

    const auto& transfer = std::get<Operation::Transfer>(operation.details());

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
        Money::fromMinorUnits(25000, rub)
        ));

    qDebug() << ledger.balance(cash.id()).minorUnits();

    qDebug() << ledger.totalBalance(rub).minorUnits(); // 875000

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
        Money::fromMinorUnits(40000, rub)
        ));

    qDebug() << ledger.balance(creditCard.id()).minorUnits()
             << ledger.debt(creditCard.id()).minorUnits()
             << ledger.totalBalance(rub).minorUnits();

    return QGuiApplication::exec();
}
