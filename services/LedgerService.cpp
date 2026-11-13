#include "LedgerService.h"
#include "LedgerReadService.h"

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
    QUuid historyVersion = QUuid::createUuid();

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
    qRegisterMetaType<AccountList>("services::AccountList");
    qRegisterMetaType<CategoryList>("services::CategoryList");
    qRegisterMetaType<OperationPage>("services::OperationPage");

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
    executeRequest(
        QStringLiteral("totalBalance"),
        [this, currencyCode](const State& state) {
            const auto currency =
                core::model::Currency::fromCode(
                    currencyCode.toStdString()
                    );

            const auto total =
                state.ledger.totalBalance(currency);

            emit totalBalanceReady(
                total.minorUnits(),
                currencyCode
                );
        }
        );
}

void LedgerService::createAccount(
    const QString& name,
    core::model::AccountType type,
    const QString& currencyCode,
    qint64 openingBalanceMinor,
    qint64 creditLimitMinor)
{
    executeCommand(
        QStringLiteral("createAccount"),
        [name, type, currencyCode,
         openingBalanceMinor, creditLimitMinor](State& state)
        {
            AccountService service{
                state.database,
                state.ledger
            };

            return service.create(
                name,
                type,
                currencyCode,
                openingBalanceMinor,
                creditLimitMinor
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

void LedgerService::updateAccount(const QUuid& id, const QString& name,
    core::model::AccountType type, const QString& currencyCode,
    qint64 openingBalanceMinor, qint64 creditLimitMinor)
{
    executeCommand(QStringLiteral("updateAccount"),
        [id, name, type, currencyCode, openingBalanceMinor, creditLimitMinor](State& state) {
            AccountService service{state.database, state.ledger};
            return service.update(id, name, type, currencyCode,
                openingBalanceMinor, creditLimitMinor);
        });
}

void LedgerService::updateCategory(const QUuid& id, const QString& name,
    core::model::CategoryType type)
{
    executeCommand(QStringLiteral("updateCategory"),
        [id, name, type](State& state) {
            CategoryService service{state.database, state.ledger};
            return service.update(id, name, type);
        });
}

void LedgerService::updateOperation(const QUuid& id, int type,
    const QUuid& accountId, const QUuid& secondaryId,
    qint64 amountMinor, QDate date, const QString& description)
{
    executeCommand(QStringLiteral("updateOperation"),
        [id, type, accountId, secondaryId, amountMinor, date, description](State& state) {
            OperationService service{state.database, state.ledger};
            return service.update(id, type, accountId, secondaryId, amountMinor, date, description);
        });
}

void LedgerService::requestAccounts()
{
    executeRequest(
        QStringLiteral("accounts"),
        [this](const State& state) {
            LedgerReadService reader{state.ledger};

            const auto result = reader.accounts();

            emit accountsReady(result);
        }
        );
}

void LedgerService::requestCategories()
{
    executeRequest(
        QStringLiteral("categories"),
        [this](const State& state) {
            LedgerReadService reader{state.ledger};

            const auto result = reader.categories();

            emit categoriesReady(result);
        }
        );
}

void LedgerService::requestOperations(
    qint64 offset,
    qint64 limit,
    const QUuid& version)
{
    executeRequest(
        QStringLiteral("operations"),
        [this, offset, limit, version](const State& state) {
            LedgerReadService reader{state.ledger};

            const bool resetRequired =
                offset > 0 &&
                version != state.historyVersion;

            auto page = reader.operations(
                resetRequired ? 0 : offset,
                limit
                );

            page.version = state.historyVersion;
            page.resetRequired = resetRequired;

            emit operationsReady(page);
        }
        );
}

void LedgerService::addIncome(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date,
    const QString& description)
{
    executeCommand(
        QStringLiteral("income"),
        [accountId, categoryId, amountMinor, date, description](
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
                date,
                description
                );
        }
        );
}

void LedgerService::addExpense(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date,
    const QString& description)
{
    executeCommand(
        QStringLiteral("expense"),
        [accountId, categoryId, amountMinor, date, description](
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
                date,
                description
                );
        }
        );
}

void LedgerService::transfer(
    const QUuid& fromAccountId,
    const QUuid& toAccountId,
    qint64 sentAmountMinor,
    QDate date,
    const QString& description)
{
    executeCommand(
        QStringLiteral("transfer"),
        [fromAccountId, toAccountId, sentAmountMinor, date, description](
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
                date,
                description
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

void LedgerService::removeOperation(const QUuid& id)
{
    executeCommand(
        QStringLiteral("removeOperation"),
        [id](State& state) {
            OperationService service{
                state.database,
                state.ledger
            };

            return service.remove(id);
        }
        );
}

void LedgerService::executeRequest(
    const QString& requestName,
    std::function<void(const State&)> action)
{
    QMetaObject::invokeMethod(
        worker_,
        [this, requestName, action = std::move(action)] {
            try {
                if (!state_) {
                    throw std::logic_error(
                        "Database is not open"
                        );
                }

                action(*state_);
            } catch (const std::exception& error) {
                emit requestFailed(
                    requestName,
                    QString::fromUtf8(error.what())
                    );
            }
        },
        Qt::QueuedConnection
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

                const QUuid nextVersion =
                    QUuid::createUuid();

                const QUuid id = action(*state_);

                state_->historyVersion = nextVersion;

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