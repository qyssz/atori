import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atori/core/storage/app_controller.dart';
import 'package:atori/core/storage/app_repository.dart';
import 'package:atori/shared/models/models.dart';

class MemorySource implements LocalDataSource {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (fail) {
      throw StateError('test write failure');
    }
    value = next;
  }
}

void main() {
  test('并发修改不同设置保留两次修改', () async {
    final source = MemorySource();
    final repo = AppRepository(source, AppData.empty());
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    await Future.wait([
      controller.updateSettings((s) => s.copyWith(theme: 'dark')),
      controller.updateSettings((s) => s.copyWith(showTeacher: false)),
    ]);
    expect(repo.data.settings.theme, 'dark');
    expect(repo.data.settings.showTeacher, isFalse);
    final restored = AppData.fromJson(objectOf(jsonDecode(source.value!)));
    expect(restored.settings.theme, 'dark');
    expect(restored.settings.showTeacher, isFalse);
  });
  test('写入失败不发布未保存的状态，之后仍可成功写入', () async {
    final source = MemorySource();
    final repo = AppRepository(source, AppData.empty());
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    source.fail = true;
    await expectLater(
      controller.saveGrade(
        const Grade(id: '1', courseName: '数学', score: 90, credit: 2),
      ),
      throwsStateError,
    );
    expect(container.read(appControllerProvider).grades, isEmpty);
    expect(repo.data.grades, isEmpty);
    source.fail = false;
    await controller.saveGrade(
      const Grade(id: '1', courseName: '数学', score: 90, credit: 2),
    );
    expect(repo.data.grades.single.id, '1');
  });
  test('并发保存串行化，无丢失更新，并可重新读取', () async {
    final source = MemorySource();
    final repo = AppRepository(source, AppData.empty());
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    await Future.wait([
      controller.saveGrade(
        const Grade(id: '1', courseName: '数学', score: 90, credit: 2),
      ),
      controller.saveGrade(
        const Grade(id: '2', courseName: '英语', score: 80, credit: 1),
      ),
    ]);
    final loaded = AppData.fromJson(
      objectOf(jsonDecode((await source.read())!)),
    );
    expect(loaded.grades.length, 2);
    await controller.clearData();
    final cleared = AppData.fromJson(
      objectOf(jsonDecode((await source.read())!)),
    );
    expect(cleared.grades, isEmpty);
    expect(cleared.courses, isEmpty);
    expect(cleared.secondClass, isEmpty);
  });
  test('非法备份拒绝且已保存数据保持原样', () async {
    final source = MemorySource();
    final repo = AppRepository(source, AppData.empty());
    await repo.save(AppData.empty());
    final before = source.value;
    await expectLater(
      repo.save(AppData.empty().copyWith(selectedTimetableId: 'missing')),
      throwsFormatException,
    );
    expect(source.value, before);
    expect(repo.data.selectedTimetableId, 'main');
  });
}
