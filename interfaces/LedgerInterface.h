#pragma once

#include "LedgerService.h"
#include "ReadListModel.h"
#include "SettingsService.h"

#include <QHash>
#include <QObject>
#include <QStringList>
#include <QUuid>

#include <functional>

namespace interfaces {

class LedgerInterface final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ isReady NOTIFY readyChanged)
    Q_PROPERTY(QString totalBalanceText READ totalBalanceText NOTIFY totalBalanceChanged)
    Q_PROPERTY(bool historyLoading READ isHistoryLoading NOTIFY historyStateChanged)
    Q_PROPERTY(bool historyHasMore READ historyHasMore NOTIFY historyStateChanged)
    Q_PROPERTY(QString historyCaption READ historyCaption NOTIFY historyStateChanged)
    Q_PROPERTY(bool commandPending READ isCommandPending NOTIFY commandStateChanged)
    Q_PROPERTY(bool canAddOperation READ canAddOperation NOTIFY availabilityChanged)
    Q_PROPERTY(bool canTransfer READ canTransfer NOTIFY availabilityChanged)
    Q_PROPERTY(QString accountsCaption READ accountsCaption NOTIFY accountsChanged)
    Q_PROPERTY(QString baseCurrencyCode READ baseCurrencyCode NOTIFY baseCurrencyChanged)
    Q_PROPERTY(int baseCurrencyIndex READ baseCurrencyIndex NOTIFY baseCurrencyChanged)
    Q_PROPERTY(QStringList currencyCodes READ currencyCodes CONSTANT)
    Q_PROPERTY(QAbstractItemModel* accountsModel READ accountsModel CONSTANT)
    Q_PROPERTY(QAbstractItemModel* categoriesModel READ categoriesModel CONSTANT)
    Q_PROPERTY(QAbstractItemModel* incomeCategoriesModel READ incomeCategoriesModel CONSTANT)
    Q_PROPERTY(QAbstractItemModel* expenseCategoriesModel READ expenseCategoriesModel CONSTANT)
    Q_PROPERTY(QAbstractItemModel* historyModel READ historyModel CONSTANT)

public:
    explicit LedgerInterface(services::LedgerService& service,
                             services::SettingsService& settings,
                             QObject* parent = nullptr);

    bool isReady() const noexcept { return ready_; }
    const QString& totalBalanceText() const noexcept { return totalBalanceText_; }
    bool isHistoryLoading() const noexcept { return historyLoading_; }
    bool historyHasMore() const noexcept { return historyHasMore_; }
    bool isCommandPending() const noexcept { return commandPending_; }
    bool canAddOperation() const noexcept;
    bool canTransfer() const noexcept;
    QString historyCaption() const;
    QString accountsCaption() const;
    QString baseCurrencyCode() const;
    int baseCurrencyIndex() const;
    QStringList currencyCodes() const;

    QAbstractItemModel* accountsModel() noexcept { return &accounts_; }
    QAbstractItemModel* categoriesModel() noexcept { return &categories_; }
    QAbstractItemModel* incomeCategoriesModel() noexcept { return &incomeCategories_; }
    QAbstractItemModel* expenseCategoriesModel() noexcept { return &expenseCategories_; }
    QAbstractItemModel* historyModel() noexcept { return &history_; }

    Q_INVOKABLE QString currentDateText() const;
    Q_INVOKABLE bool setBaseCurrencyCode(const QString& code);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void reloadHistory();
    Q_INVOKABLE void loadMoreHistory();

    Q_INVOKABLE bool createAccount(const QString& name, int type,
        const QString& currencyCode, const QString& openingBalance,
        const QString& creditLimit);
    Q_INVOKABLE bool createCategory(const QString& name, int type);
    Q_INVOKABLE bool updateAccount(const QString& id, const QString& name,
        int type, const QString& currencyCode, const QString& openingBalance,
        const QString& creditLimit);
    Q_INVOKABLE bool updateCategory(const QString& id, const QString& name, int type);
    Q_INVOKABLE bool updateOperation(const QString& id, int type,
        const QString& accountId, const QString& secondaryId,
        const QString& amount, const QString& date);
    Q_INVOKABLE bool addIncome(const QString& accountId, const QString& categoryId,
        const QString& amount, const QString& date);
    Q_INVOKABLE bool addExpense(const QString& accountId, const QString& categoryId,
        const QString& amount, const QString& date);
    Q_INVOKABLE bool transfer(const QString& fromAccountId, const QString& toAccountId,
        const QString& amount, const QString& date);
    Q_INVOKABLE bool removeAccount(const QString& id);
    Q_INVOKABLE bool removeCategory(const QString& id);
    Q_INVOKABLE bool removeOperation(const QString& id);

signals:
    void readyChanged();
    void totalBalanceChanged();
    void historyStateChanged();
    void commandStateChanged();
    void availabilityChanged();
    void accountsChanged();
    void baseCurrencyChanged();
    void commandFinished(const QString& commandName, const QString& id);
    void errorOccurred(const QString& message);

private:
    void requestHistoryPage();
    bool executeUiCommand(const QString& name, const std::function<void()>& action);
    qint64 readAccountAmount(const QString& accountId, const QString& amount) const;

    services::LedgerService& service_;
    services::SettingsService& settings_;

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
    qint64 historyTotalCount_ = 0;
    QUuid historyVersion_;
    bool commandPending_ = false;
    QString pendingCommand_;
    QHash<QUuid, int> accountDecimalPlaces_;

    ReadListModel accounts_{{"id", "name", "type", "typeText", "currencyCode", "openingInput", "limitInput", "isCreditCard",
        "primaryLabel", "primaryText", "balanceText", "creditLimitText", "debtText"}, this};
    ReadListModel categories_{{"id", "name", "type", "typeText"}, this};
    ReadListModel incomeCategories_{{"id", "name", "type", "typeText"}, this};
    ReadListModel expenseCategories_{{"id", "name", "type", "typeText"}, this};
    ReadListModel history_{{"id", "dateText", "dateIso", "accountId", "secondaryId", "amountInput", "type", "typeText", "accountText",
        "secondaryAccountText", "categoryText", "primaryAmountText",
        "secondaryAmountText", "descriptionText"}, this};
};

} // namespace interfaces
