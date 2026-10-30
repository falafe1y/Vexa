#pragma once

#include <QSqlQuery>
#include <QVariantMap>

// The current row of a query as column name -> value
QVariantMap rowMap(const QSqlQuery& query);
