#include "BankImportRepository.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

BankImportRepository::BankImportRepository(Database& database)
    : database_(database.connection())
{
}

QString BankImportRepository::lastError() const { return lastError_; }
void BankImportRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<BankImportRepository::BankCsvProfileRecord>
BankImportRepository::loadBankCsvProfiles()
{
    QVector<BankCsvProfileRecord> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, name, configuration_json "
            "FROM bank_csv_profiles ORDER BY name COLLATE NOCASE, id"))) {
        setLastError(query.lastError().text());
        return result;
    }
    while (query.next()) {
        result.append({
            query.value(0).toString(),
            query.value(1).toString(),
            query.value(2).toString()
        });
    }
    return result;
}

bool BankImportRepository::saveBankCsvProfile(
    const QString& id,
    const QString& name,
    const QString& configurationJson
    )
{
    if (id.trimmed().isEmpty() || name.trimmed().isEmpty() ||
        configurationJson.trimmed().isEmpty()) {
        setLastError(QStringLiteral("Invalid bank CSV profile"));
        return false;
    }
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO bank_csv_profiles("
        "id, name, configuration_json, created_at, updated_at) "
        "VALUES(?, ?, ?, ?, ?) "
        "ON CONFLICT(id) DO UPDATE SET "
        "name = excluded.name, "
        "configuration_json = excluded.configuration_json, "
        "updated_at = excluded.updated_at"));
    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    query.addBindValue(id);
    query.addBindValue(name.trimmed());
    query.addBindValue(configurationJson);
    query.addBindValue(now);
    query.addBindValue(now);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool BankImportRepository::deleteBankCsvProfile(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "DELETE FROM bank_csv_profiles WHERE id = ?"));
    query.addBindValue(id);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return query.numRowsAffected() > 0;
}

QVector<BankCategoryRule> BankImportRepository::loadBankCategoryRules(QString* error) const
{
    if (error) error->clear();
    QVector<BankCategoryRule> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
        "SELECT r.pattern,r.match_mode,r.type,r.category_id,r.match_field FROM bank_category_rules r "
        "JOIN categories c ON c.id=r.category_id AND c.type=r.type "
        "WHERE c.is_archived=0 ORDER BY r.type,r.pattern,r.match_mode"))) {
        if (error) *error = query.lastError().text(); return result;
    }
    while (query.next()) result.append({query.value(0).toString(), query.value(1).toString(),
        query.value(3).toString(), query.value(2).toInt() == 0 ? CategoryType::Income : CategoryType::Expense, query.value(4).toString()});
    return result;
}

bool BankImportRepository::deleteBankCategoryRule(const QString& pattern,
    const QString& matchMode, CategoryType type)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("DELETE FROM bank_category_rules WHERE pattern=? AND match_mode=? AND type=?"));
    query.addBindValue(pattern.trimmed());
    query.addBindValue(matchMode); query.addBindValue(type == CategoryType::Income ? 0 : 1);
    if (!query.exec()) { setLastError(query.lastError().text()); return false; }
    return true;
}

QVector<BankRecipientRule> BankImportRepository::loadBankRecipientRules(QString* error) const
{
    if (error) error->clear();
    QVector<BankRecipientRule> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
        "SELECT pattern,match_field,match_mode,type,recipient_name FROM bank_recipient_rules "
        "ORDER BY type,pattern,match_field,match_mode"))) {
        if (error) *error = query.lastError().text();
        return result;
    }
    while (query.next()) {
        result.append({query.value(0).toString(), query.value(1).toString(), query.value(2).toString(),
            query.value(3).toInt() == 0 ? CategoryType::Income : CategoryType::Expense, query.value(4).toString()});
    }
    return result;
}

bool BankImportRepository::deleteBankRecipientRule(const QString& pattern, const QString& field,
    const QString& mode, CategoryType type)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "DELETE FROM bank_recipient_rules WHERE pattern=? AND match_field=? AND match_mode=? AND type=?"));
    query.addBindValue(pattern);
    query.addBindValue(field);
    query.addBindValue(mode);
    query.addBindValue(type == CategoryType::Income ? 0 : 1);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

QMap<QString, QString> BankImportRepository::loadBankImportLinks(QString* error) const
{
    if (error) error->clear();
    QSqlQuery query(database_);
    QMap<QString, QString> links;
    if (!query.exec(QStringLiteral("SELECT row_key,transaction_id FROM bank_import_links"))) {
        if (error) *error = query.lastError().text();
        return links;
    }
    while (query.next()) links.insert(query.value(0).toString(), query.value(1).toString());
    if (query.lastError().isValid() && error) *error = query.lastError().text();
    return links;
}
