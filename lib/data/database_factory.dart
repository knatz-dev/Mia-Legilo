import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'app_database.dart';

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'mia_legilo.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}

AppDatabase openInMemoryDatabase() => AppDatabase(NativeDatabase.memory());
