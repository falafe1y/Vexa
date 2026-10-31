#include "MoexBenchmarkParser.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QStringList>

QVariantList investmentBenchmarkIndices() {
    return {QVariantMap{{"key","index:IMOEX"},{"kind","index"},{"symbol","IMOEX"},{"name",QStringLiteral("Индекс Мосбиржи · цены")},{"currency","RUB"},{"board","SNDX"},{"totalReturn",false}},
            QVariantMap{{"key","index:MCFTR"},{"kind","index"},{"symbol","MCFTR"},{"name",QStringLiteral("Индекс Мосбиржи · полная доходность брутто")},{"currency","RUB"},{"board","RTSI"},{"totalReturn",true}}};
}
namespace {
QString currencyCode(QString code) {
    code=code.toUpper();if(code=="SUR" || code=="RUR")code="RUB";
    return QStringList{"RUB","USD","EUR","CNY"}.contains(code)?code:QString();
}
}
bool parseBenchmarkPage(const QByteArray& payload,const QVariantMap& descriptor,QVariantList& rows,int& next,QString& error) {
    QJsonParseError parseError;const auto doc=QJsonDocument::fromJson(payload,&parseError);next=-1;
    if(parseError.error!=QJsonParseError::NoError || !doc.isObject()){error=QStringLiteral("Мосбиржа вернула некорректные данные истории.");return false;}
    const auto table=doc.object().value("history").toObject();QMap<QString,int> cols;
    const auto names=table.value("columns").toArray();for(int i=0;i<names.size();++i)cols.insert(names[i].toString().toUpper(),i);
    for(const auto& required:{"BOARDID","TRADEDATE","CLOSE","CURRENCYID"})if(!cols.contains(required)){error=QStringLiteral("В истории нет необходимых полей цены или валюты.");return false;}
    if(!table.value("data").isArray()){error=QStringLiteral("В истории отсутствует список записей.");return false;}
    const auto cell=[&](const QJsonArray& row,const char* name){const auto i=cols.value(name,-1);return i>=0 && i<row.size()?row[i]:QJsonValue();};
    for(const auto& value:table.value("data").toArray()){
        const auto row=value.toArray();const auto date=QDate::fromString(cell(row,"TRADEDATE").toString(),Qt::ISODate);if(!date.isValid()){error=QStringLiteral("В истории найдена некорректная дата.");return false;}
        if(cols.contains("SECID") && !descriptor.value("symbol").toString().isEmpty() && cell(row,"SECID").toString()!=descriptor.value("symbol").toString()){
            error=QStringLiteral("Сервер вернул историю другого инструмента.");return false;
        }
        const auto board=cell(row,"BOARDID").toString();int priority=-1;
        if(descriptor.value("kind")=="index") {if(board==descriptor.value("board"))priority=10;}
        else for(const auto& b:descriptor.value("boards").toList()){
            const auto item=b.toMap();const auto from=QDate::fromString(item.value("from").toString(),Qt::ISODate),to=QDate::fromString(item.value("to").toString(),Qt::ISODate);
            if(item.value("id")==board && (!from.isValid() || date>=from) && (!to.isValid() || date<=to))priority=qMax(priority,item.value("primary").toBool()?20:10);
        }
        if(priority<0)continue;
        const auto session=cell(row,"TRADINGSESSION").toVariant().toInt();priority=priority*10+(session==3?3:0);
        const auto close=cell(row,"CLOSE");const auto code=currencyCode(cell(row,"CURRENCYID").toString());
        const long double scaled=static_cast<long double>(close.toDouble())*1'000'000;
        QVariant price;if(close.isDouble() && std::isfinite(scaled) && scaled>=1 && scaled<std::numeric_limits<qint64>::max())price=qint64(std::llround(scaled));
        rows.append(QVariantMap{{"price_date",date.toString(Qt::ISODate)},{"price_micros",price},{"currency",code},{"board",board},{"priority",priority},
            {"issues",price.isNull()?QStringLiteral("missing_close"):(code.isEmpty()?QStringLiteral("missing_currency"):QString())}});
    }
    const auto cursor=doc.object().value("history.cursor").toObject();QMap<QString,int> cursorCols;
    const auto cn=cursor.value("columns").toArray();for(int i=0;i<cn.size();++i)cursorCols.insert(cn[i].toString().toUpper(),i);
    const auto data=cursor.value("data").toArray();
    if(!cursorCols.contains("INDEX") || !cursorCols.contains("TOTAL") || !cursorCols.contains("PAGESIZE") || data.isEmpty()){error=QStringLiteral("Не удалось проверить полноту истории Мосбиржи.");return false;}
    const auto cr=data.first().toArray();const auto c=[&](const char* name){int i=cursorCols.value(name,-1);return i>=0 && i<cr.size()?cr[i].toInt(-1):-1;};
    const int start=c("INDEX"),total=c("TOTAL"),size=c("PAGESIZE");
    if(start<0 || total<0 || size<=0 || total>100000 || start>total || table.value("data").toArray().size()!=qMin(size,total-start)){error=QStringLiteral("Некорректная нумерация страниц истории.");return false;}
    if(start+size<total)next=start+size;return true;
}
bool mergeBenchmarkRows(const QVariantList& rows,QVariantList& prices,QString& error) {
    QMap<QString,QVariantMap> byDate;
    for(const auto& value:rows){const auto r=value.toMap();const auto date=r.value("price_date").toString();
        if(!byDate.contains(date) || r.value("priority").toInt()>byDate.value(date).value("priority").toInt())byDate[date]=r;
        else if(r.value("priority")==byDate[date].value("priority") && (r.value("price_micros")!=byDate[date].value("price_micros") || r.value("currency")!=byDate[date].value("currency"))){error=QStringLiteral("Для одной даты найдены неоднозначные цены ориентира.");return false;}
    }
    for(const auto& r:byDate)prices.append(r);return true;
}
