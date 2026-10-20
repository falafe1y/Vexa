#include "../storage/AutoBackup.h"

#include <QTemporaryDir>
#include <QTest>

using namespace AutoBackup;

class AutoBackupTest : public QObject {
    Q_OBJECT

private slots:
    void namesUseLocalTimeAndOnlyOwnPattern() {
        const QDateTime when(QDate(2026, 10, 20), QTime(9, 30, 5), QTimeZone::UTC);
        // The name shows the time as the device sees it, with the same clock the copy was made by
        QCOMPARE(fileName(QDateTime(QDate(2026, 10, 20), QTime(9, 30, 5))),
                 QStringLiteral("vexa-auto-2026-10-20_09-30-05.vexabackup"));
        QVERIFY(isAutoName(fileName(when)));
        QVERIFY(!isAutoName(QStringLiteral("vexa-test.vexabackup")));
        QVERIFY(!isAutoName(QStringLiteral("vexa-auto-2026-10-20_09-30-05.vexabackup.partial")));
    }

    void dueAfterTwentyFourHoursOnTheDeviceClock() {
        State state;
        state.enabled = true;
        state.folder = QStringLiteral("/copies");
        const QDateTime now(QDate(2026, 10, 21), QTime(9, 0, 0));
        // Never copied yet: due at once
        QVERIFY(isDue(state, now, true));
        // Copied 23 hours 59 minutes ago: not yet
        state.lastBackup = now.addSecs(-(24 * 3600 - 60));
        QVERIFY(!isDue(state, now, true));
        // Copied exactly 24 hours ago: due
        state.lastBackup = now.addSecs(-24 * 3600);
        QVERIFY(isDue(state, now, true));
    }

    void disabledOrWithoutFolderOrPasswordIsNeverDue() {
        State state;
        const QDateTime now(QDate(2026, 10, 21), QTime(9, 0, 0));
        QVERIFY(!isDue(state, now, true));           // disabled
        state.enabled = true;
        QVERIFY(!isDue(state, now, true));           // no folder
        state.folder = QStringLiteral("/copies");
        QVERIFY(!isDue(state, now, false));          // no password
        QVERIFY(isDue(state, now, true));
    }

    void failedAttemptWaitsAnHour() {
        State state;
        state.enabled = true;
        state.folder = QStringLiteral("/copies");
        const QDateTime now(QDate(2026, 10, 21), QTime(9, 0, 0));
        state.lastAttempt = now.addSecs(-30 * 60);
        state.lastError = QStringLiteral("Нет места");
        QVERIFY(!isDue(state, now, true));
        state.lastAttempt = now.addSecs(-61 * 60);
        QVERIFY(isDue(state, now, true));
    }

    void retentionKeepsTheNewestSevenOwnCopies() {
        QStringList names;
        for (int day = 1; day <= 9; ++day)
            names.append(QStringLiteral("vexa-auto-2026-10-%1_09-00-00.vexabackup").arg(day, 2, 10, QLatin1Char('0')));
        names.append(QStringLiteral("manual-export.vexabackup"));   // not ours: never removed
        const QStringList removed = expired(names, KeepCopies);
        QCOMPARE(removed.size(), 2);
        QCOMPARE(removed.at(0), QStringLiteral("vexa-auto-2026-10-01_09-00-00.vexabackup"));
        QCOMPARE(removed.at(1), QStringLiteral("vexa-auto-2026-10-02_09-00-00.vexabackup"));
        QVERIFY(expired(QStringList{QStringLiteral("vexa-auto-2026-10-01_09-00-00.vexabackup")}, KeepCopies).isEmpty());
    }

    void stateSurvivesRestart() {
        QTemporaryDir dir;
        const auto file = dir.filePath(QStringLiteral("auto-backup.json"));
        State written;
        written.enabled = true;
        written.folder = QStringLiteral("content://tree/primary%3ABackups");
        written.lastBackup = QDateTime(QDate(2026, 10, 20), QTime(9, 30, 0));
        written.lastError.clear();
        QString error;
        QVERIFY(save(file, written, error));
        State read;
        QVERIFY(load(file, read, error));
        QVERIFY(read.enabled);
        QCOMPARE(read.folder, written.folder);
        QCOMPARE(read.lastBackup, written.lastBackup);
    }

    void missingStateFileMeansDisabled() {
        QTemporaryDir dir;
        State state;
        state.enabled = true;
        QString error;
        QVERIFY(load(dir.filePath(QStringLiteral("absent.json")), state, error));
        QVERIFY(!state.enabled);
        QVERIFY(error.isEmpty());
    }
};

QTEST_APPLESS_MAIN(AutoBackupTest)
#include "AutoBackupTest.moc"
