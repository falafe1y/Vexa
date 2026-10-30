#include "SqlRow.h"

#include <QSqlRecord>

QVariantMap rowMap(const QSqlQuery& query) {
    QVariantMap row; const auto record=query.record();
    for(int i=0;i<record.count();++i) row.insert(record.fieldName(i),query.value(i));
    return row;
}
