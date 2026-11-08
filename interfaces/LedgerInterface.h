#pragma once

#include "LedgerService.h"

#include <QHash>
#include <QObject>
#include <QString>
#include <QUuid>
#include <QVariantList>
#include <QtTypes>

#include <functional>

namespace interfaces {

class LedgerInterface final : public QObject
{
    Q_OBJECT

    Q_PROPERTY(
        bool ready
            READ isReady
                NOTIFY readyChanged
        )

    Q_PROPERTY(
        QString totalBalanceText
            READ totalBalanceText
                NOTIFY totalBalanceChanged
        )

    Q_PROPERTY(
        bool historyLoading
            READ isHistoryLoading
                NOTIFY historyStateChanged
        )

    Q_PROPERTY(
        bool historyHasMore
            READ historyHasMore
                NOTIFY historyStateChanged
        )

    Q_PROPERTY(
        bool commandPending
            READ isCommandPending
                NOTIFY commandStateChanged
        )

public:
    explicit LedgerInterface(
        services::LedgerService& service,
        QString totalCurrencyCode,
        QObject* parent = nullptr
        );

    [[nodiscard]] bool isReady() const noexcept
    {
        return ready_;
    }

    [[nodiscard]] const QString& totalBalanceText() const noexcept
    {
        return totalBalanceText_;
    }

    [[nodiscard]] bool isHistoryLoading() const noexcept
    {
        return historyLoading_;
    }

    [[nodiscard]] bool historyHasMore() const noexcept
    {
        return historyHasMore_;
    }

    [[nodiscard]] bool isCommandPending() const noexcept
    {
        return commandPending_;
    }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void reloadHistory();
    Q_INVOKABLE void loadMoreHistory();

    Q_INVOKABLE bool createAccount(
        const QString& name,
        int type,
        const QString& currencyCode,
        const QString& openingBalance,
        const QString& creditLimit
        );

    Q_INVOKABLE bool createCategory(
        const QString& name,
        int type
        );

    Q_INVOKABLE bool addIncome(
        const QString& accountId,
        const QString& categoryId,
        const QString& amount,
        const QString& date
        );

    Q_INVOKABLE bool addExpense(
        const QString& accountId,
        const QString& categoryId,
        const QString& amount,
        const QString& date
        );

    Q_INVOKABLE bool transfer(
        const QString& fromAccountId,
        const QString& toAccountId,
        const QString& amount,
        const QString& date
        );

    Q_INVOKABLE bool removeAccount(const QString& id);
    Q_INVOKABLE bool removeCategory(const QString& id);
    Q_INVOKABLE bool removeOperation(const QString& id);

signals:
    void readyChanged();
    void totalBalanceChanged();
    void historyStateChanged();
    void commandStateChanged();

    void accountsReceived(const QVariantList& items);
    void categoriesReceived(const QVariantList& items);

    void historyReceived(
        const QVariantList& items,
        bool replace
        );

    void commandFinished(
        const QString& commandName,
        const QString& id
        );

    void errorOccurred(const QString& message);

private:
    void requestHistoryPage();

    bool executeUiCommand(
        const QString& commandName,
        const std::function<void()>& action
        );

    [[nodiscard]] qint64 readAccountAmount(
        const QString& accountId,
        const QString& amount
        ) const;

    services::LedgerService& service_;

    QString totalCurrencyCode_;
    int totalDecimalPlaces_ = 0;
    QString totalBalanceText_;

    bool ready_ = false;

    bool historyLoading_ = false;
    bool historyHasMore_ = false;
    bool historyReplace_ = true;
    bool historyReloadPending_ = false;

    qint64 historyNextOffset_ = 0;
    qint64 historyPageSize_ = 50;
    QUuid historyVersion_;

    bool commandPending_ = false;
    QString pendingCommand_;

    QHash<QUuid, int> accountDecimalPlaces_;
};

} // namespace interfaces