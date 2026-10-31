#pragma once
#include <QByteArray>
#include <QString>
#include <memory>

// Where the key of the encrypted database is kept: a store of the operating system
class DatabaseKeyStore {
public:
    virtual ~DatabaseKeyStore() = default;
    // Empty key + empty error means no key exists; lookup never creates a key.
    virtual QByteArray existing(QString& error) = 0;
    virtual bool save(const QByteArray& key, QString& error) = 0;
};
std::shared_ptr<DatabaseKeyStore> nativeDatabaseKeyStore();
