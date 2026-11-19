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
            if (!historyFilter_.accountId.isNull()
                && !accountDecimalPlaces_.contains(historyFilter_.accountId)) {
                setHistoryAccountId({});
            }
            emit accountsChanged();
            emit availabilityChanged();
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::categoriesReady, this,
        [this](const services::CategoryList& categories) {
            const auto previousHistoryCategoryName = historyCategoryName();
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
            if (!historyFilter_.categoryId.isNull() && historyCategoryName().isEmpty()) {
                historyFilter_.categoryId = {};
                historyFilterUpdated();
            } else if (historyCategoryName() != previousHistoryCategoryName) {
                emit historyCategoryNameChanged();
            }
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

    connect(&service_, &services::LedgerService::expenseSummaryReady, this,
        [this](const services::ExpenseSummary& summary, const QString& currencyCode) {
            if (!finishExpenseSummaryRequest()) return;

            expenseSummaryFailed_ = false;
            expenseTotalText_ = presentation::money(
                summary.totalMinor, totalDecimalPlaces_, currencyCode);
            expenseSummary_.setRows(presentation::expenseSummaryRows(
                summary, totalDecimalPlaces_, currencyCode));
            emit expenseSummaryChanged();
        }, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::operationsReady,
            this, &LedgerInterface::acceptHistoryPage, Qt::QueuedConnection);

    connect(&service_, &services::LedgerService::requestFailed, this,
        [this](const QString& request, const QString& message) {
            if (request == QStringLiteral("operations")) {
                historyRequestFailed();
            }
            if (request == QStringLiteral("expenseSummary")) {
                if (finishExpenseSummaryRequest()) {
                    expenseSummaryFailed_ = true;
                    expenseTotalText_.clear();
                    expenseSummary_.setRows({});
                    emit expenseSummaryChanged();
                }
                return;
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
        [this](const QString& message) {
            expenseSummaryFailed_ = true;
            emit expenseSummaryChanged();
            emit errorOccurred(message);
        }, Qt::QueuedConnection);
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

QString LedgerInterface::expenseSummaryCaption() const
{
    if (expenseSummaryLoading_) return QStringLiteral("Расчёт расходов…");
    if (expenseSummaryFailed_) return QStringLiteral("Не удалось рассчитать расходы");
    if (!ready_) return QStringLiteral("Загрузка расходов…");
    return QStringLiteral("Расходов пока нет");
}

QString LedgerInterface::baseCurrencyCode() const { return settings_.baseCurrencyCode(); }
QStringList LedgerInterface::currencyCodes() const { return {"RUB", "USD", "EUR", "CNY"}; }
int LedgerInterface::baseCurrencyIndex() const
{
    return static_cast<int>(currencyCodes().indexOf(settings_.baseCurrencyCode()));
}

QString LedgerInterface::currentDateText() const
{
    return QDate::currentDate().toString(presentation::operationDateFormat);
}

bool LedgerInterface::setBaseCurrencyCode(const QString& code)
{
    try {
        settings_.setBaseCurrencyCode(code);
        totalCurrencyCode_ = settings_.baseCurrencyCode();
        totalDecimalPlaces_ = core::model::Currency::fromCode(
            totalCurrencyCode_.toStdString()).decimalPlaces();
        emit baseCurrencyChanged();
        if (ready_) {
            service_.requestTotalBalance(totalCurrencyCode_);
            reloadHistory();
            expenseSummary_.setRows({});
            expenseTotalText_.clear();
            reloadExpenseSummary();
            emit expenseSummaryChanged();
        }
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
    reloadExpenseSummary();
    reloadHistory();
}

void LedgerInterface::reloadExpenseSummary()
{
    if (expenseSummaryLoading_) {
        expenseSummaryReloadPending_ = true;
        return;
    }
    expenseSummaryLoading_ = true;
    service_.requestExpenseSummary(totalCurrencyCode_);
    emit expenseSummaryChanged();
}

bool LedgerInterface::finishExpenseSummaryRequest()
{
    expenseSummaryLoading_ = false;
    if (!expenseSummaryReloadPending_) return true;

    expenseSummaryReloadPending_ = false;
    reloadExpenseSummary();
    return false;
}

} // namespace interfaces
