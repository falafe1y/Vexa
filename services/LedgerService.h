#pragma once

#include "Account.h"
#include "Category.h"
#include "ReadData.h"

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
        qint64 openingBalanceMinor,
        qint64 creditLimitMinor = 0
        );

    void createCategory(
        const QString& name,
        core::model::CategoryType type
        );

    void updateAccount(const QUuid& id, const QString& name,
        core::model::AccountType type, const QString& currencyCode,
        qint64 openingBalanceMinor, qint64 creditLimitMinor);
    void updateCategory(const QUuid& id, const QString& name,
        core::model::CategoryType type);
    void updateOperation(const QUuid& id, int type,
        const QUuid& accountId, const QUuid& secondaryId,
        qint64 amountMinor, QDate date);

    void requestAccounts();
    void requestCategories();
    void requestOperations(
            qint64 offset = 0,
            qint64 limit = 50,
            const QUuid& version = QUuid{}
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
    void removeOperation(const QUuid& id);

signals:
    void accountsReady(
        const services::AccountList& accounts
        );

    void categoriesReady(
        const services::CategoryList& categories
        );

    void operationsReady(
        const services::OperationPage& page
        );

    void requestFailed(
        const QString& requestName,
        const QString& message
        );

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

    void executeRequest(
        const QString& requestName,
        std::function<void(const State&)> action
        );

    void executeCommand(
        const QString& commandName,
        std::function<QUuid(State&)> action
        );

    QThread databaseThread_;
    QObject* worker_ = nullptr;

    std::unique_ptr<State> state_;
};

} // namespace services