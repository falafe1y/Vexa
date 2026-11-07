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

using namespace core::model;

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    try {
        const auto filePath = QDir::current().filePath(
            QStringLiteral("vexa-mvp-test-database.sqlite3")
            );

        {
            core::db::Database database{filePath};
            qDebug() << "База открыта:" << filePath;
        }

        qDebug() << "Соединение закрыто";
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
