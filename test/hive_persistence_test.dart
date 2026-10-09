import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:atori/core/storage/app_repository.dart';
import 'package:atori/shared/models/models.dart';

void main() {
  test('Hive关闭并重新打开后，课程与设置仍存在', () async {
    final directory = await Directory.systemTemp.createTemp('atori-hive-');
    addTearDown(() async {
      await Hive.close();
      final resolved = await directory.resolveSymbolicLinks();
      final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
      if (!resolved.startsWith('$tempRoot${Platform.pathSeparator}')) {
        throw StateError('Unsafe temporary cleanup path');
      }
      await Directory(resolved).delete(recursive: true);
    });
    Hive.init(directory.path);
    final first = await Hive.openBox<String>('persistence');
    final repo = AppRepository(HiveDataSource(first), AppData.empty());
    await repo.save(
      AppData.empty().copyWith(
        courses: [
          const Course(
            id: 'math',
            name: '持久化数学',
            weekday: 1,
            startSection: 1,
            endSection: 2,
            startWeek: 1,
            endWeek: 20,
          ),
        ],
        settings: AppSettings(theme: 'dark'),
      ),
    );
    await first.close();
    final reopened = await Hive.openBox<String>('persistence');
    final stored = await HiveDataSource(reopened).read();
    final data = AppData.fromJson(objectOf(jsonDecode(stored!)));
    expect(data.courses.single.name, '持久化数学');
    expect(data.settings.theme, 'dark');
  });
}
