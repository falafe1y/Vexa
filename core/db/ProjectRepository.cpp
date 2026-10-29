#include "ProjectRepository.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

ProjectRepository::ProjectRepository(Database& database)
    : database_(database.connection())
{
}

QString ProjectRepository::lastError() const { return lastError_; }
void ProjectRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<Project> ProjectRepository::loadProjects()
{
    QVector<Project> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, name FROM projects "
            "WHERE is_archived = 0 "
            "ORDER BY created_at, name COLLATE NOCASE"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(Project(
            query.value(0).toString(),
            query.value(1).toString()));
    }
    return result;
}

bool ProjectRepository::insertProject(const Project& project)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO projects(id, name, is_archived, created_at, updated_at) "
        "VALUES (?, ?, 0, ?, ?)"));
    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    query.addBindValue(project.id());
    query.addBindValue(project.name().trimmed());
    query.addBindValue(now);
    query.addBindValue(now);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool ProjectRepository::updateProject(const Project& project)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE projects SET name = ?, updated_at = ? "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(project.name().trimmed());
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    query.addBindValue(project.id());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Project was not found"));
        return false;
    }
    return true;
}

bool ProjectRepository::archiveProject(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE projects SET is_archived = 1, updated_at = ? "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Project was not found"));
        return false;
    }
    return true;
}
