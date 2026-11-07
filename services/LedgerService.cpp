#include "LedgerService.h"

#include "Currency.h"
#include "Database.h"
#include "Ledger.h"

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

} // namespace services