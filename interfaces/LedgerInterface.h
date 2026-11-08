#pragma once

#include "LedgerService.h"

#include <QObject>
#include <QString>
#include <QUuid>
#include <QVariantList>
#include <QtTypes>

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

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void reloadHistory();
    Q_INVOKABLE void loadMoreHistory();

signals:
    void readyChanged();
    void totalBalanceChanged();
    void historyStateChanged();

    void accountsReceived(const QVariantList& items);
    void categoriesReceived(const QVariantList& items);

    // replace = true: заменить историю.
    // replace = false: добавить строки к существующей истории.
    void historyReceived(const QVariantList& items, bool replace);

    void errorOccurred(const QString& message);

private:
    void requestHistoryPage();

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
};

} // namespace interfaces
