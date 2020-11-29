import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'VisitModel.dart';

class DBProvider {
  DBProvider._();

  static final DBProvider db = DBProvider._();

  Database _database;

  Future<Database> get database async {
    if (_database != null) return _database;
    _database = await initDB();
    return _database;
  }

  initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "CompassDB.db");
    return await openDatabase(path, version: 1, onOpen: (db) {},
        onCreate: (Database db, int version) async {
          await db.execute("CREATE TABLE Visit ("
              "id INTEGER PRIMARY KEY,"
              "city TEXT,"
              "count INTEGER"
              ")");
        });
  }

  newVisit(Visit newVisit) async {
    final db = await database;
    var table = await db.rawQuery("SELECT MAX(id)+1 as id FROM Visit");
    int id = table.first["id"];
    var raw = await db.rawInsert(
        "INSERT Into Visit (id, city, count)"
            " VALUES (?, ?, ?)",
        [id, newVisit.city, newVisit.count]);
    return raw;
  }

  updateVisit(Visit newVisit) async {
    final db = await database;
    var res = await db.update("Visit", newVisit.toMap(),
        where: "id = ?", whereArgs: [newVisit.id]);
    return res;
  }

  getVisit(int id) async {
    final db = await database;
    var res = await db.query("Visit", where: "id = ?", whereArgs: [id]);
    return res.isNotEmpty ? Visit.fromMap(res.first) : null;
  }

  Future<List<Visit>> getAllVisits() async {
    final db = await database;
    var res = await db.query("Visit");
    List<Visit> list = res.isNotEmpty ? res.map((c) => Visit.fromMap(c)).toList() : [];
    return list;
  }

  deleteVisit(int id) async {
    final db = await database;
    return db.delete("Visit", where: "id = ?", whereArgs: [id]);
  }

  deleteAll() async {
    final db = await database;
    db.rawDelete("Delete * from Visit");
  }
}