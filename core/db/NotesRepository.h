#pragma once
#include "Database.h"

#include <QString>

// The text of the notes page: one row of the notes table.
class NotesRepository
{
public:
    explicit NotesRepository(Database& database);

    // exists, when given, tells whether the row is already in the table
    bool load(QString& text, bool* exists = nullptr);
    bool save(const QString& text);
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
