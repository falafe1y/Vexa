#pragma once

#include "ReadData.h"

#include <QString>
#include <QVariantList>
#include <QVariantMap>

namespace interfaces::presentation {

inline const auto operationDateFormat = QStringLiteral("dd.MM.yyyy");

QString money(qint64 minor, int decimals, const QString& currencyCode);
QString accountsCaption(int count);
QVariantMap accountRow(const services::AccountData& account);
QVariantMap categoryRow(const services::CategoryData& category);
QVariantMap operationRow(const services::OperationData& operation);

QVariantList expenseSummaryRows(const services::ExpenseSummary& summary,
    int decimals, const QString& currencyCode);

} // namespace interfaces::presentation
