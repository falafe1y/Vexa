#include "LedgerInterface.h"

#include "Currency.h"
#include "LedgerPresentation.h"

#include <QDate>

#include <exception>

namespace interfaces {

LedgerInterface::LedgerInterface(services::LedgerService& service,
                                 services::SettingsService& settings,
                                 QObject* parent)
    : QObject(parent), service_(service), settings_(settings),
      totalCurrencyCode_(settings.baseCurrencyCode())
{
    totalDecimalPlaces_ = core::model::Currency::fromCode(
        totalCurrencyCode_.toStdString()).decimalPlaces();
    totalBalanceText_ = presentation::money(0, totalDecimalPlaces_, totalCurrencyCode_);

    connect(this, &LedgerInterface::commandStateChanged,
            this, &LedgerInterface::availabilityChanged);
    connect(this, &LedgerInterface::readyChanged,
            this, &LedgerInterface::availabilityChanged);

    connect(&service_, &services::LedgerService::loaded, this,
        [this](qint64, qint64, qint64) {
            ready_ = true;
            emit readyChanged();
            refresh();
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::changed,
            this, &LedgerInterface::refresh, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::accountsReady, this,
        [this](const services::AccountList& accounts) {
            QVariantList rows;
            rows.reserve(static_cast<qsizetype>(accounts.size()));
            accountDecimalPlaces_.clear();
            for (const auto& account : accounts) {
                accountDecimalPlaces_.insert(account.id, account.decimalPlaces);
                rows.push_back(presentation::accountRow(account));
            }
            accounts_.setRows(rows);
            emit accountsChanged();
            emit availabilityChanged();
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::categoriesReady, this,
        [this](const services::CategoryList& categories) {
            QVariantList all, income, expense;
            for (const auto& category : categories) {
                const auto row = presentation::categoryRow(category);
                all.push_back(row);
                if (category.type == core::model::CategoryType::Income) income.push_back(row);
                else expense.push_back(row);
            }
            categories_.setRows(all);
            incomeCategories_.setRows(income);
            expenseCategories_.setRows(expense);
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::totalBalanceReady, this,
        [this](qint64 amount, const QString& currencyCode) {
            if (currencyCode != totalCurrencyCode_) return;
            const auto text = presentation::money(amount, totalDecimalPlaces_, currencyCode);
            if (text != totalBalanceText_) {
                totalBalanceText_ = text;
                emit totalBalanceChanged();
            }
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::operationsReady, this,
        [this](const services::OperationPage& page) {
            if (!historyLoading_) return;
            historyLoading_ = false;
            if (historyReloadPending_) {
                historyReloadPending_ = false;
                reloadHistory();
                return;
            }

            QVariantList rows;
            rows.reserve(static_cast<qsizetype>(page.items.size()));
            for (const auto& operation : page.items) {
                rows.push_back(presentation::operationRow(operation));
            }

            if (historyReplace_ || page.resetRequired) history_.setRows(rows);
            else history_.appendRows(rows);

            historyNextOffset_ = page.nextOffset;
            historyVersion_ = page.version;
            historyTotalCount_ = page.totalCount;
            historyHasMore_ = page.hasMore;
            historyReplace_ = false;
            emit historyStateChanged();
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::requestFailed, this,
        [this](const QString& request, const QString& message) {
            if (request == QStringLiteral("operations")) {
                historyLoading_ = false;
                if (historyReloadPending_) {
                    historyReloadPending_ = false;
                    reloadHistory();
                } else emit historyStateChanged();
            }
            emit errorOccurred(message);
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::commandSucceeded, this,
        [this](const QString& command, const QUuid& id) {
            if (!commandPending_ || pendingCommand_ != command) return;
            commandPending_ = false;
            pendingCommand_.clear();
            emit commandStateChanged();
            emit commandFinished(command, id.toString(QUuid::WithoutBraces));
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::commandFailed, this,
        [this](const QString& command, const QString& message) {
            if (commandPending_ && pendingCommand_ == command) {
                commandPending_ = false;
                pendingCommand_.clear();
                emit commandStateChanged();
            }
            emit errorOccurred(message);
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::failed, this,
        [this](const QString& message) { emit errorOccurred(message); }, Qt::QueuedConnection);
}

bool LedgerInterface::canAddOperation() const noexcept
{
    return ready_ && !commandPending_ && accounts_.count() > 0;
}

bool LedgerInterface::canTransfer() const noexcept
{
    return ready_ && !commandPending_ && accounts_.count() > 1;
}

QString LedgerInterface::accountsCaption() const
{
    return presentation::accountsCaption(accounts_.count());
}

QString LedgerInterface::historyCaption() const
{
    if (historyLoading_ && history_.count() == 0) return QStringLiteral("Загрузка истории…");
    if (historyTotalCount_ == 0) return QStringLiteral("Операций пока нет");
    return QStringLiteral("Показано %1 из %2 операций").arg(history_.count()).arg(historyTotalCount_);
}

QString LedgerInterface::baseCurrencyCode() const { return settings_.baseCurrencyCode(); }
QStringList LedgerInterface::currencyCodes() const { return {"RUB", "USD", "EUR", "CNY"}; }
int LedgerInterface::baseCurrencyIndex() const
{
    return static_cast<int>(currencyCodes().indexOf(settings_.baseCurrencyCode()));
}

QString LedgerInterface::currentDateText() const
{
    return QDate::currentDate().toString(Qt::ISODate);
}

bool LedgerInterface::setBaseCurrencyCode(const QString& code)
{
    try {
        settings_.setBaseCurrencyCode(code);
        totalCurrencyCode_ = settings_.baseCurrencyCode();
        totalDecimalPlaces_ = core::model::Currency::fromCode(
            totalCurrencyCode_.toStdString()).decimalPlaces();
        emit baseCurrencyChanged();
        if (ready_) service_.requestTotalBalance(totalCurrencyCode_);
        return true;
    } catch (const std::exception& error) {
        emit baseCurrencyChanged();
        emit errorOccurred(QString::fromUtf8(error.what()));
        return false;
    }
}

void LedgerInterface::refresh()
{
    if (!ready_) return;
    service_.requestAccounts();
    service_.requestCategories();
    service_.requestTotalBalance(totalCurrencyCode_);
    reloadHistory();
}

void LedgerInterface::reloadHistory()
{
    if (!ready_) return;
    if (historyLoading_) {
        historyReloadPending_ = true;
        return;
    }
    historyNextOffset_ = 0;
    historyVersion_ = QUuid{};
    historyHasMore_ = true;
    historyReplace_ = true;
    requestHistoryPage();
}

void LedgerInterface::loadMoreHistory()
{
    if (ready_ && !historyLoading_ && historyHasMore_) requestHistoryPage();
}

void LedgerInterface::requestHistoryPage()
{
    historyLoading_ = true;
    emit historyStateChanged();
    service_.requestOperations(historyNextOffset_, historyPageSize_, historyVersion_);
}

} // namespace interfaces
