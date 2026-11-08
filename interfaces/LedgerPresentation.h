#pragma once

#include "ReadData.h"

#include <QString>
#include <QVariantMap>

namespace interfaces::presentation {

QString money(qint64 minor, int decimals, const QString& currencyCode);
QString accountsCaption(int count);
QVariantMap accountRow(const services::AccountData& account);
QVariantMap categoryRow(const services::CategoryData& category);
QVariantMap operationRow(const services::OperationData& operation);

} // namespace interfaces::presentation
