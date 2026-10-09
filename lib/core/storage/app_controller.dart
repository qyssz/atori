import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import 'app_repository.dart';

final repositoryProvider = Provider<AppRepository>(
  (ref) => throw StateError('Repository must be initialized'),
);
final appControllerProvider = NotifierProvider<AppController, AppData>(
  AppController.new,
);

class AppController extends Notifier<AppData> {
  Future<void> _pending = Future.value();
  @override
  AppData build() => ref.watch(repositoryProvider).data;
  Future<void> change(FutureOr<AppData> Function(AppData) transform) {
    final task = _pending.then((_) async {
      final next = await transform(state);
      await ref.read(repositoryProvider).save(next);
      state = next;
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<void> saveCourse(Course course) => change(
    (data) => data.copyWith(
      courses: [...data.courses.where((c) => c.id != course.id), course],
    ),
  );
  Future<void> deleteCourse(String id) => change(
    (data) =>
        data.copyWith(courses: data.courses.where((c) => c.id != id).toList()),
  );
  Future<void> saveGrade(Grade grade) => change(
    (data) => data.copyWith(
      grades: [...data.grades.where((g) => g.id != grade.id), grade],
    ),
  );
  Future<void> deleteGrade(String id) => change(
    (data) =>
        data.copyWith(grades: data.grades.where((g) => g.id != id).toList()),
  );
  Future<void> settings(AppSettings settings) =>
      change((data) => data.copyWith(settings: settings));
  Future<void> updateSettings(AppSettings Function(AppSettings) transform) =>
      change((data) => data.copyWith(settings: transform(data.settings)));
  Future<void> selectTimetable(String id) =>
      change((data) => data.copyWith(selectedTimetableId: id));
  Future<void> saveTimetable(Timetable table) => change(
    (data) => data.copyWith(
      timetables: [...data.timetables.where((t) => t.id != table.id), table],
      selectedTimetableId: table.id,
    ),
  );
  Future<void> deleteTimetable(String id) => change((data) {
    final remaining = data.timetables.where((t) => t.id != id).toList();
    if (remaining.isEmpty) {
      throw const FormatException('至少保留一份课表');
    }
    return data.copyWith(
      timetables: remaining,
      selectedTimetableId: data.selectedTimetableId == id
          ? remaining.first.id
          : data.selectedTimetableId,
      courses: data.courses.where((c) => c.timetableId != id).toList(),
    );
  });
  Future<void> restore(AppData backup) => change((_) => backup);
  Future<void> clearData() => change((_) => AppData.empty());
  Future<void> clearActivities() =>
      change((data) => data.copyWith(secondClass: [], volunteer: []));
  Future<void> reloadActivities() => change((data) async {
    final mocks = MockDataSource();
    final second = await mocks.load(
      'second_class',
      SecondClassActivity.fromJson,
    );
    final volunteer = await mocks.load('volunteer', VolunteerActivity.fromJson);
    return data.copyWith(secondClass: second, volunteer: volunteer);
  });
}
