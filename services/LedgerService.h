#pragma once

#include "Account.h"
#include "Category.h"

#include <QDate>
#include <QObject>
#include <QString>
#include <QThread>
#include <QUuid>
#include <QtTypes>

#include <functional>
#include <memory>

namespace services {

class LedgerService final : public QObject
{
    Q_OBJECT

public:
    explicit LedgerService(QObject* parent = nullptr);
    ~LedgerService() override;

    void open(const QString& filePath);

    void requestTotalBalance(const QString& currencyCode);

    void createAccount(
        const QString& name,
        core::model::AccountType type,
        const QString& currencyCode,
        qint64 openingBalanceMinor
        );

    void createCategory(
        const QString& name,
        core::model::CategoryType type
        );

    void addIncome(
        const QUuid& accountId,
        const QUuid& categoryId,
        qint64 amountMinor,
        QDate date
        );

    void addExpense(
        const QUuid& accountId,
        const QUuid& categoryId,
        qint64 amountMinor,
        QDate date
        );

    void transfer(
        const QUuid& fromAccountId,
        const QUuid& toAccountId,
        qint64 sentAmountMinor,
        QDate date
        );

    void removeAccount(const QUuid& id);
    void removeCategory(const QUuid& id);

signals:
    void loaded(
        qint64 accountCount,
        qint64 categoryCount,
        qint64 operationCount
        );

    void totalBalanceReady(
        qint64 totalMinor,
        const QString& currencyCode
        );

    void commandSucceeded(
        const QString& commandName,
        const QUuid& entityId
        );

    void commandFailed(
        const QString& commandName,
        const QString& message
        );

    void removalCompleted(
        const QString& entityType,
        const QUuid& id,
        bool archived   // true - архивация, false - удаление из БД
        );

    void changed();

    void failed(const QString& message);

private:
    struct State;

    void executeCommand(
        const QString& commandName,
        std::function<QUuid(State&)> action
        );

    QThread databaseThread_;
    QObject* worker_ = nullptr;

    std::unique_ptr<State> state_;
};

} // namespace services