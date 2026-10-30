#include "PriceHistory.h"

#include <QSqlError>
#include <QSqlQuery>

bool savePriceHistory(QSqlDatabase& database, QString& error, const QString& kind, const QString& id, qint64 price,
    const QDateTime& at, const QString& currency, const QString& source, const QString& terms) {
    if((kind!="crypto" && kind!="investment") || id.isEmpty() || !at.isValid() || currency.isEmpty() || source.isEmpty()){
        error=QStringLiteral("Некорректная историческая котировка");return false;
    }
    QSqlQuery q(database);
    q.prepare("INSERT INTO "+kind+"_price_history(asset_id,quoted_at,source,price_micros,currency,observed_at,terms_json) VALUES(?,?,?,?,?,?,?) "
              "ON CONFLICT(asset_id,quoted_at,source) DO UPDATE SET price_micros=excluded.price_micros,currency=excluded.currency,observed_at=excluded.observed_at,terms_json=excluded.terms_json");
    q.addBindValue(id);q.addBindValue(at.toMSecsSinceEpoch());q.addBindValue(source);q.addBindValue(price);
    q.addBindValue(currency);q.addBindValue(QDateTime::currentMSecsSinceEpoch());q.addBindValue(terms);
    if(!q.exec()){error=q.lastError().text();return false;}return true;
}
