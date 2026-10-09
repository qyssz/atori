import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/models.dart';

abstract interface class LocalDataSource {
  Future<String?> read();
  Future<void> write(String value);
}

class HiveDataSource implements LocalDataSource {
  HiveDataSource(this.box);
  final Box<String> box;
  @override
  Future<String?> read() async => box.get('snapshot');
  @override
  Future<void> write(String value) => box.put('snapshot', value);
}

class MockDataSource {
  Future<List<T>> load<T>(String asset, T Function(JsonMap) decode) async {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/mock/$asset.json'),
    );
    if (raw is! List) {
      throw const FormatException('示例数据格式无效');
    }
    return raw.map((entry) => decode(objectOf(entry))).toList();
  }

  Future<AppData> initialData() async {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1 + 35));
    final data = AppData(
      timetables: [
        Timetable(id: 'main', name: '示例学期 · 可修改', startDate: monday),
      ],
      selectedTimetableId: 'main',
      courses: await load('courses', Course.fromJson),
      grades: await load('grades', Grade.fromJson),
      secondClass: await load('second_class', SecondClassActivity.fromJson),
      volunteer: await load('volunteer', VolunteerActivity.fromJson),
    );
    data.validate();
    return data;
  }
}

class AppRepository {
  AppRepository(this.source, this.data, {this.preferences});
  final LocalDataSource source;
  final SharedPreferences? preferences;
  AppData data;
  int get initialTab => (preferences?.getInt('lastTab') ?? 0).clamp(0, 3);
  static Future<AppRepository> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>('atori_v1');
    final source = HiveDataSource(box);
    final raw = await source.read();
    final data = raw == null
        ? (const bool.fromEnvironment('USE_MOCK_DATA', defaultValue: true)
              ? await MockDataSource().initialData()
              : AppData.empty())
        : AppData.fromJson(objectOf(jsonDecode(raw)));
    if (raw == null) {
      await source.write(jsonEncode(data.toJson()));
    }
    return AppRepository(
      source,
      data,
      preferences: await SharedPreferences.getInstance(),
    );
  }

  Future<void> save(AppData next) async {
    next.validate();
    final encoded = jsonEncode(next.toJson());
    await source.write(encoded);
    data = next;
  }

  Future<void> saveTab(int tab) async {
    await preferences?.setInt('lastTab', tab);
  }

  Future<void> reloadMockActivities() async {
    final mocks = MockDataSource();
    final second = await mocks.load(
      'second_class',
      SecondClassActivity.fromJson,
    );
    final volunteer = await mocks.load('volunteer', VolunteerActivity.fromJson);
    await save(data.copyWith(secondClass: second, volunteer: volunteer));
  }
}
