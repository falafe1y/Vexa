#include "NotesRepository.h"

#include <QSqlError>
#include <QSqlQuery>

NotesRepository::NotesRepository(Database& database)
    : database_(database.connection())
{
}

QString NotesRepository::lastError() const { return lastError_; }
void NotesRepository::setLastError(const QString& error) { lastError_ = error; }

bool NotesRepository::load(QString& text, bool* exists)
{
    if (exists) *exists = false;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral("SELECT text FROM notes WHERE id = 1"))) {
        setLastError(query.lastError().text());
        return false;
    }
    text.clear();
    if (query.next()) {
        text = query.value(0).toString();
        if (exists) *exists = true;
    } else if (query.lastError().isValid()) {
        setLastError(query.lastError().text());
        return false;
    }
    setLastError({});
    return true;
}

bool NotesRepository::save(const QString& text)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO notes(id,text) VALUES(1,?) "
        "ON CONFLICT(id) DO UPDATE SET text=excluded.text"));
    query.addBindValue(text.isNull() ? QStringLiteral("") : text);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    setLastError({});
    return true;
}
