import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'model.dart';

class MessageDB {
  static final MessageDB instance = MessageDB._init();

  static Database? _database;

  MessageDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('P2P.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
        'CREATE TABLE $messagesTableName(_id PRIMARY KEY, type TEXT NOT NULL,msg TEXT NOT NULL);');
    await db.execute(
        'CREATE TABLE $conversationsTableName(_id PRIMARY KEY, converser TEXT NOT NULL,type TEXT NOT NULL,msg TEXT NOT NULL,timestamp TEXT NOT NULL, ack TEXT NOT NULL);');
  }

  void insertIntoMessagesTable(MessageFromDB message) async {
    final db = await instance.database;
    final id = await db.insert(messagesTableName, message.toJson());
    return;
  }
  void insertIntoConversationsTable(ConversationFromDB message) async {
    final db = await instance.database;
    final id = await db.insert(conversationsTableName, message.toJson());
    return;
  }
  Future<MessageFromDB?> readFromMessagesTable(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      messagesTableName,
      columns: MessageTableFields.values,
      where: '${MessageTableFields.id}=?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty)
      return MessageFromDB.fromJson(maps.first);
    else
      return null;
  }
  Future<ConversationFromDB?> readFromConversationsTable(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      conversationsTableName,
      columns: ConversationTableFields.values,
      where: '${ConversationTableFields.id}=?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty)
      return ConversationFromDB.fromJson(maps.first);
    else
      return null;
  }

  Future<List<MessageFromDB>> readAllFromMessagesTable() async {
    final db = await instance.database;
    final result = await db.query(
      messagesTableName,
    );
    return result.map((json) => MessageFromDB.fromJson(json)).toList();
  }
  Future<List<ConversationFromDB>> readAllFromConversationsTable() async {
    final db = await instance.database;
    final result = await db.query(
      conversationsTableName,
    );
    return result.map((json) => ConversationFromDB.fromJson(json)).toList();
  }
  Future<int> updateMessageTable(MessageFromDB msg) async {
    final db = await instance.database;
    return db.update(messagesTableName, msg.toJson(),
        where: '${MessageTableFields.id}=?', whereArgs: [msg.id]);
  }
  Future<int> updateConversationTable(ConversationFromDB msg) async {
    final db = await instance.database;
    return db.update(conversationsTableName, msg.toJson(),
        where: '${ConversationTableFields.id}=?', whereArgs: [msg.id]);
  }

  Future<int> deleteFromMessagesTable(String id) async {
    final db = await instance.database;
    return db.delete(messagesTableName,
        where: '${MessageTableFields.id}=?', whereArgs: [id]);
  }
  Future<int> deleteFromConversationsTable(String id) async {
    final db = await instance.database;
    return db.delete(conversationsTableName,
        where: '${ConversationTableFields.id}=?', whereArgs: [id]);
  }
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
