// sqltest.c -- a minimal demo of SQLite running as a BareMetal app:
// creates a table on a real BMFS-backed database file, inserts a few
// rows (across two transactions, to exercise the rollback journal --
// see port/sqlite_port/sqlite_vfs.c), queries them back, and prints
// the result set. build with build-app.sh.
//
// This is also a valid *nix program of course.
//
// Unlike curltest.c (which reaches network sockets/TLS through libcurl
// on top of net_shim.c/tls_shim.c), this exercises port/sqlite_port/
// sqlite_vfs.c -- SQLite's own on-disk format read/written straight
// against posix_shim.c/bmfs.c's open/read/write/lseek/close/unlink/
// ftruncate, no network involved.
//
// DB_PATH is removed first so the demo is idempotent (safe to run
// again on a disk image that already has one from a previous run)
// rather than accumulating rows or hitting UNIQUE/PRIMARY KEY
// conflicts on a second boot.

#include <stdio.h>
#include <stdlib.h>

#include <sqlite3.h>

#define DB_PATH "sqltest.db"

static int die(sqlite3 *db, const char *what)
{
	printf("%s: %s\n", what, sqlite3_errmsg(db));
	sqlite3_close(db);
	return 1;
}

static int print_row(void *unused, int argc, char **argv, char **colname)
{
	(void)unused;
	for (int i = 0; i < argc; i++)
		printf("  %-8s = %s\n", colname[i], argv[i] ? argv[i] : "NULL");
	printf("  --\n");
	return 0;
}

int main(void)
{
	printf("BareMetal sqltest -- SQLite %s\n", sqlite3_libversion());
	printf("database: %s\n\n", DB_PATH);

	remove(DB_PATH);

	sqlite3 *db;
	if (sqlite3_open(DB_PATH, &db) != SQLITE_OK)
		return die(db, "sqlite3_open");

	char *err = NULL;

	if (sqlite3_exec(db,
		"CREATE TABLE readings ("
		"  id     INTEGER PRIMARY KEY,"
		"  sensor TEXT NOT NULL,"
		"  value  REAL NOT NULL"
		");",
		NULL, NULL, &err) != SQLITE_OK) {
		printf("CREATE TABLE failed: %s\n", err);
		sqlite3_free(err);
		sqlite3_close(db);
		return 1;
	}

	// Two separate transactions -- each COMMIT drives a full rollback-
	// journal cycle (journal created, written, synced, then deleted --
	// see sqlite_vfs.c) against the same BMFS file.
	if (sqlite3_exec(db,
		"BEGIN;"
		"INSERT INTO readings (sensor, value) VALUES ('temp',     21.5);"
		"INSERT INTO readings (sensor, value) VALUES ('humidity', 47.0);"
		"COMMIT;",
		NULL, NULL, &err) != SQLITE_OK) {
		printf("first transaction failed: %s\n", err);
		sqlite3_free(err);
		sqlite3_close(db);
		return 1;
	}

	if (sqlite3_exec(db,
		"BEGIN;"
		"INSERT INTO readings (sensor, value) VALUES ('temp',     21.8);"
		"INSERT INTO readings (sensor, value) VALUES ('pressure', 1013.2);"
		"COMMIT;",
		NULL, NULL, &err) != SQLITE_OK) {
		printf("second transaction failed: %s\n", err);
		sqlite3_free(err);
		sqlite3_close(db);
		return 1;
	}

	printf("readings, most recent first:\n");
	if (sqlite3_exec(db,
		"SELECT id, sensor, value FROM readings ORDER BY id DESC;",
		print_row, NULL, &err) != SQLITE_OK) {
		printf("SELECT failed: %s\n", err);
		sqlite3_free(err);
		sqlite3_close(db);
		return 1;
	}

	sqlite3_stmt *stmt;
	if (sqlite3_prepare_v2(db, "SELECT COUNT(*), AVG(value) FROM readings;", -1, &stmt, NULL) == SQLITE_OK) {
		if (sqlite3_step(stmt) == SQLITE_ROW) {
			printf("\n%d row(s), average value %.2f\n",
				sqlite3_column_int(stmt, 0), sqlite3_column_double(stmt, 1));
		}
		sqlite3_finalize(stmt);
	}

	sqlite3_close(db);

	return 0;
}
