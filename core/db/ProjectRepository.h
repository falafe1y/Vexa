#pragma once
#include "Database.h"
#include "../model/planning/Project.h"
#include <QString>
#include <QVector>

// Projects: named groups of operations for one purpose of spending.
class ProjectRepository
{
public:
    explicit ProjectRepository(Database& database);

    QVector<Project> loadProjects();
    bool insertProject(const Project& project);
    bool updateProject(const Project& project);
    bool archiveProject(const QString& id);
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
