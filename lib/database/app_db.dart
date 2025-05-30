import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  Database? _localDb;

  Future<Database> get localDb async {
    if (_localDb != null) return _localDb!;
    _localDb = await _initLocalDatabase();
    return _localDb!;
  }

  AppDb() {
    _initLocalDatabase();
  }

  Future<Database> _initLocalDatabase() async {
    return await openDatabase(
      join(await getDatabasesPath(), 'local_data.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          // Users table
          await txn.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              name TEXT,
              email TEXT,
              profile_picture TEXT,
              is_synced INTEGER
            )
          ''');

          // Messages table
          await txn.execute('''
            CREATE TABLE messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sender_id INTEGER,
              receiver_id INTEGER,
              content TEXT,
              message_type TEXT,
              timestamp INTEGER,
              is_synced INTEGER
            )
          ''');

          // User relations table
          await txn.execute('''
            CREATE TABLE user_relations (
              user1_id INTEGER,
              user2_id INTEGER,
              is_synced INTEGER,
              PRIMARY KEY (user1_id, user2_id)
            )
          ''');

          // User health profile table
          await txn.execute('''
            CREATE TABLE user_health_profile (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER UNIQUE,
              height REAL,
              weight REAL,
              daily_calorie_goal INTEGER,
              last_updated INTEGER,
              is_synced INTEGER DEFAULT 0,
              FOREIGN KEY (user_id) REFERENCES users (id)
            )
          ''');

          await txn.execute('''
            CREATE TABLE meals (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER,
              name TEXT,
              calories INTEGER,
              consumed_at INTEGER,
              created_at INTEGER,
              is_synced INTEGER DEFAULT 0,
              FOREIGN KEY (user_id) REFERENCES users (id)
            )
          ''');
        });
      },
    );
  }
}
