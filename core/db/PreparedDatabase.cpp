#include "PreparedDatabase.h"
#include "DatabaseSchema.h"

PreparedDatabase::PreparedDatabase(const QString& path, const QByteArray& key)
    : db_(path, key)
    , database_(db_.connection())
{
    if (!db_.isOpen()) {
        lastError_ = db_.lastError();
        return;
    }

    DatabaseSchema schema(db_, lastError_);
    if (!schema.prepare() || !schema.seedDefaults()) {
        db_.close();
    }
}

bool PreparedDatabase::isOpen() const { return database_.isOpen(); }
QString PreparedDatabase::lastError() const { return lastError_; }
QString PreparedDatabase::databasePath() const { return database_.databaseName(); }
Database& PreparedDatabase::database() { return db_; }
