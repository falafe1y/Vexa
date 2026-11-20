#include "LedgerInterface.h"

#include "LedgerPresentation.h"

namespace interfaces {

QString LedgerInterface::historyAccountId() const
{
    return historyFilter_.accountId.isNull() ? QString{}
        : historyFilter_.accountId.toString(QUuid::WithoutBraces);
}

QString LedgerInterface::historyCategoryId() const
{
    return historyFilter_.categoryId.isNull() ? QString{}
        : historyFilter_.categoryId.toString(QUuid::WithoutBraces);
}

QString LedgerInterface::historyCategoryName() const
{
    if (historyFilter_.categoryId.isNull()) return {};
    const auto id = historyCategoryId();
    for (int i = 0; i < categories_.count(); ++i) {
        const auto row = categories_.row(i);
        if (row.value(QStringLiteral("id")).toString() == id) {
            return row.value(QStringLiteral("name")).toString();
        }
    }
    return {};
}

void LedgerInterface::setHistoryAccountId(const QString& id)
{
    const QUuid accountId{id};
    if ((!id.isEmpty() && !accountDecimalPlaces_.contains(accountId))
        || historyFilter_.accountId == accountId) return;
    historyFilter_.accountId = accountId;
    historyFilterUpdated();
}

void LedgerInterface::setHistorySearchText(const QString& text)
{
    if (historyFilter_.searchText == text) return;
    historyFilter_.searchText = text;
    historyFilterUpdated();
}

void LedgerInterface::setHistoryOperationType(int type)
{
    if (type < -1 || type > 2 || historyFilter_.type == type) return;
    historyFilter_.type = type;
    historyFilterUpdated();
}

void LedgerInterface::filterHistory(const QString& accountId, const QString& categoryId)
{
    historyFilter_ = {};
    historyFilter_.accountId = QUuid{accountId};
    if (!accountDecimalPlaces_.contains(historyFilter_.accountId)) {
        historyFilter_.accountId = QUuid{};
    }
    historyFilter_.categoryId = QUuid{categoryId};
    if (historyCategoryName().isEmpty()) historyFilter_.categoryId = QUuid{};
    historyFilterUpdated();
}

void LedgerInterface::resetHistoryFilters()
{
    filterHistory({}, {});
}

void LedgerInterface::historyFilterUpdated()
{
    historyFailed_ = false;
    reloadHistory();
    emit historyFilterChanged();
    emit historyCategoryNameChanged();
}

QString LedgerInterface::historyCaption() const
{
    if (!ready_ || (historyLoading_ && !historyHasResult_)) {
        return QStringLiteral("Загрузка истории…");
    }
    if (historyLoading_) return {};
    if (historyFailed_) return QStringLiteral("Не удалось загрузить историю");
    if (historyTotalCount_ == 0) {
        if (!historyFilter_.searchText.trimmed().isEmpty()) return QStringLiteral("Ничего не найдено");
        return QStringLiteral("Операций пока нет");
    }
    return {};
}

void LedgerInterface::reloadHistory()
{
    if (!ready_) return;
    if (historyLoading_) {
        if (!historyReloadPending_) {
            historyReloadPending_ = true;
            emit historyStateChanged();
        }
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
    historyFailed_ = false;
    emit historyStateChanged();
    service_.requestOperations(historyNextOffset_, historyPageSize_,
        historyVersion_, historyFilter_, totalCurrencyCode_);
}

void LedgerInterface::acceptHistoryPage(const services::OperationPage& page)
{
    if (!historyLoading_) return;
    if (historyReloadPending_) {
        historyLoading_ = false;
        historyReloadPending_ = false;
        reloadHistory();
        return;
    }

    QVariantList rows;
    rows.reserve(static_cast<qsizetype>(page.items.size()));
    for (const auto& operation : page.items) {
        rows.push_back(presentation::operationRow(operation, historyFilter_.accountId));
    }
    const bool replace = historyReplace_ || page.resetRequired;
    if (replace) historyDays_.clear();
    for (const auto& day : page.days) {
        historyDays_.insert(day.date.toString(presentation::operationDateFormat),
            presentation::operationDayRow(day, page.decimalPlaces, page.currencyCode));
    }
    if (replace) history_.setRows(rows);
    else history_.appendRows(rows);

    historyNextOffset_ = page.nextOffset;
    historyVersion_ = page.version;
    historyTotalCount_ = page.totalCount;
    historyHasMore_ = page.hasMore;
    historyReplace_ = false;
    historyHasResult_ = true;
    historyLoading_ = false;
    emit historyStateChanged();
}

void LedgerInterface::historyRequestFailed()
{
    historyLoading_ = false;
    if (historyReloadPending_) {
        historyReloadPending_ = false;
        reloadHistory();
        return;
    }
    historyFailed_ = true;
    emit historyStateChanged();
}

} // namespace interfaces
