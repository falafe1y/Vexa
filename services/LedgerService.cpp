#include "LedgerService.h"

#include "Currency.h"
#include "Database.h"
#include "Ledger.h"
#include "AccountService.h"
#include "CategoryService.h"
#include "OperationService.h"
#include "ArchiveService.h"

#include <QMetaObject>

#include <exception>
#include <stdexcept>
#include <utility>

namespace services {

struct LedgerService::State
{
    core::db::Database database;
    core::model::Ledger ledger;

    explicit State(const QString& filePath)
        : database{filePath},
        ledger{
            core::model::Ledger::fromStoredData(
                database.loadAccounts(),
                database.loadCategories(),
                database.loadOperations()
                )
        }
    {
    }
};

LedgerService::LedgerService(QObject* parent)
    : QObject(parent),
    worker_(new QObject)
{
    databaseThread_.setObjectName(
        QStringLiteral("VexaDatabase")
        );

    worker_->moveToThread(&databaseThread_);

    connect(
        &databaseThread_,
        &QThread::finished,
        worker_,
        &QObject::deleteLater
        );

    databaseThread_.start();
}

LedgerService::~LedgerService()
{
    // Уничтожаем журнал и закрываем БД в рабочем потоке.
    QMetaObject::invokeMethod(
        worker_,
        [this] {
            state_.reset();
        },
        Qt::BlockingQueuedConnection
        );

    databaseThread_.quit();
    databaseThread_.wait();
}

void LedgerService::open(const QString& filePath)
{
    QMetaObject::invokeMethod(
        worker_,
        [this, filePath] {
            try {
                if (state_) {
                    throw std::logic_error(
                        "Database is already open"
                        );
                }

                auto candidate =
                    std::make_unique<State>(filePath);

                const qint64 accountCount =
                    candidate->ledger.accountCount();

                const qint64 categoryCount =
                    candidate->ledger.categoryCount();

                const qint64 operationCount =
                    candidate->ledger.operationCount();

                state_ = std::move(candidate);

                emit loaded(
                    accountCount,
                    categoryCount,
                    operationCount
                    );
            } catch (const std::exception& error) {
                emit failed(
                    QString::fromUtf8(error.what())
                    );
            }
        },
        Qt::QueuedConnection
        );
}

void LedgerService::requestTotalBalance(
    const QString& currencyCode)
{
    QMetaObject::invokeMethod(
        worker_,
        [this, currencyCode] {
            try {
                if (!state_) {
                    throw std::logic_error(
                        "Database is not open"
                        );
                }

                const auto currency =
                    core::model::Currency::fromCode(
                        currencyCode.toStdString()
                        );

                const auto total =
                    state_->ledger.totalBalance(currency);

                emit totalBalanceReady(
                    total.minorUnits(),
                    currencyCode
                    );
            } catch (const std::exception& error) {
                emit failed(
                    QString::fromUtf8(error.what())
                    );
            }
        },
        Qt::QueuedConnection
        );
}

void LedgerService::createAccount(
    const QString& name,
    core::model::AccountType type,
    const QString& currencyCode,
    qint64 openingBalanceMinor)
{
    executeCommand(
        QStringLiteral("createAccount"),
        [name, type, currencyCode, openingBalanceMinor](
            State& state)
        {
            AccountService service{
                state.database,
                state.ledger
            };

            return service.create(
                name,
                type,
                currencyCode,
                openingBalanceMinor
                );
        }
        );
}

void LedgerService::createCategory(
    const QString& name,
    core::model::CategoryType type)
{
    executeCommand(
        QStringLiteral("createCategory"),
        [name, type](State& state) {
            CategoryService service{
                state.database,
                state.ledger
            };

            return service.create(name, type);
        }
        );
}

void LedgerService::addIncome(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date)
{
    executeCommand(
        QStringLiteral("income"),
        [accountId, categoryId, amountMinor, date](
            State& state)
        {
            OperationService service{
                state.database,
                state.ledger
            };

            return service.income(
                accountId,
                categoryId,
                amountMinor,
                date
                );
        }
        );
}

void LedgerService::addExpense(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date)
{
    executeCommand(
        QStringLiteral("expense"),
        [accountId, categoryId, amountMinor, date](
            State& state)
        {
            OperationService service{
                state.database,
                state.ledger
            };

            return service.expense(
                accountId,
                categoryId,
                amountMinor,
                date
                );
        }
        );
}

void LedgerService::transfer(
    const QUuid& fromAccountId,
    const QUuid& toAccountId,
    qint64 sentAmountMinor,
    QDate date)
{
    executeCommand(
        QStringLiteral("transfer"),
        [fromAccountId, toAccountId, sentAmountMinor, date](
            State& state)
        {
            OperationService service{
                state.database,
                state.ledger
            };

            return service.transfer(
                fromAccountId,
                toAccountId,
                sentAmountMinor,
                date
                );
        }
        );
}

void LedgerService::removeAccount(const QUuid& id)
{
    executeCommand(
        QStringLiteral("removeAccount"),
        [this, id](State& state) {
            ArchiveService service{
                state.database,
                state.ledger
            };

            const auto result = service.removeAccount(id);

            emit removalCompleted(
                QStringLiteral("account"),
                id,
                result == ArchiveService::Result::Archived
                );

            return id;
        }
        );
}

void LedgerService::removeCategory(const QUuid& id)
{
    executeCommand(
        QStringLiteral("removeCategory"),
        [this, id](State& state) {
            ArchiveService service{
                state.database,
                state.ledger
            };

            const auto result = service.removeCategory(id);

            emit removalCompleted(
                QStringLiteral("category"),
                id,
                result == ArchiveService::Result::Archived
                );

            return id;
        }
        );
}

void LedgerService::executeCommand(
    const QString& commandName,
    std::function<QUuid(State&)> action)
{
    QMetaObject::invokeMethod(
        worker_,
        [this, commandName, action = std::move(action)] {
            try {
                if (!state_) {
                    throw std::logic_error(
                        "Database is not open"
                        );
                }

                const QUuid id = action(*state_);

                emit commandSucceeded(commandName, id);
                emit changed();
            } catch (const std::exception& error) {
                emit commandFailed(
                    commandName,
                    QString::fromUtf8(error.what())
                    );
            }
        },
        Qt::QueuedConnection
        );
}

} // namespace services