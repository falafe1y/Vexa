#include "FinanceRepository.h"
#include "../core/db/CipherDriver.h"
#include "../core/db/DatabaseSchema.h"

#include "../core/model/money/Currency.h"

#include <QDir>
#include <QMap>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFileInfo>
#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QSaveFile>
#include <QStringList>
#include <QTimeZone>
#include <QUuid>

#include <cmath>

FinanceRepository::FinanceRepository(const QString& databasePath, const QByteArray& databaseKey,
                                     std::shared_ptr<DatabaseKeyStore> keyStore)
    : keyStore_(keyStore ? std::move(keyStore) : nativeDatabaseKeyStore())
    , db_(databasePath, databaseKey)
    , database_(db_.connection())
{
    if (!db_.isOpen()) {
        setLastError(db_.lastError());
        return;
    }

    DatabaseSchema schema(db_, lastError_);
    if (!schema.prepare() || !schema.seedDefaults()) {
        db_.close();
    }
}

FinanceRepository::~FinanceRepository() = default;

bool FinanceRepository::isOpen() const { return database_.isOpen(); }
QString FinanceRepository::lastError() const { return lastError_; }
QString FinanceRepository::databasePath() const { return database_.databaseName(); }
Database& FinanceRepository::database() { return db_; }
std::shared_ptr<DatabaseKeyStore> FinanceRepository::keyStore() const { return keyStore_; }

void FinanceRepository::setLastError(const QString& error) { lastError_ = error; }

