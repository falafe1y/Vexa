#pragma once

#include <QString>

namespace core::db {

class Database final
{
public:
    explicit Database(const QString& filePath);
    ~Database();

    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;
};

} // namespace core::db
