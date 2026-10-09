import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:atori/shared/models/models.dart';
import 'package:atori/features/grades/domain/grade_calculator.dart';

Course course({
  String id = 'c1',
  WeekType type = WeekType.all,
  int start = 1,
  int end = 20,
  int first = 1,
  int last = 2,
  int day = 1,
}) => Course(
  id: id,
  name: '数学',
  weekday: day,
  startSection: first,
  endSection: last,
  startWeek: start,
  endWeek: end,
  weekType: type,
);
Grade grade(String id, double score, double credit, {bool included = true}) =>
    Grade(
      id: id,
      courseName: id,
      score: score,
      credit: credit,
      includedInGpa: included,
    );

void main() {
  test('第二课堂报名时间兼容旧备份并验证日期顺序', () {
    final json = {
      'id': 'activity',
      'title': '阅读',
      'category': '文化',
      'location': '图书馆',
      'startTime': '2026-10-16T14:00:00+08:00',
      'endTime': '2026-10-16T16:00:00+08:00',
      'status': 'available',
    };
    expect(SecondClassActivity.fromJson(json).registrationStart, isNull);
    final withRegistration = {
      ...json,
      'registrationStart': '2026-10-09T08:00:00+08:00',
      'registrationEnd': '2026-10-15T18:00:00+08:00',
    };
    final activity = SecondClassActivity.fromJson(withRegistration);
    expect(
      SecondClassActivity.fromJson(activity.toJson()).registrationStart,
      activity.registrationStart,
    );
    expect(
      () => SecondClassActivity.fromJson({
        ...withRegistration,
        'registrationEnd': '2026-10-01T08:00:00+08:00',
      }),
      throwsFormatException,
    );
    expect(
      () => SecondClassActivity.fromJson({
        ...json,
        'registrationStart': '2026-10-09T08:00:00+08:00',
      }),
      throwsFormatException,
    );
    expect(
      () => Timetable.fromJson({
        'id': 't',
        'name': '秋',
        'startDate': '2026-10-09',
      }),
      throwsFormatException,
    );
  });
  group('课程规则', () {
    test('单双周与边界', () {
      final odd = course(type: WeekType.odd, start: 3, end: 9);
      expect(odd.activeInWeek(1), isFalse);
      expect(odd.activeInWeek(3), isTrue);
      expect(odd.activeInWeek(4), isFalse);
      expect(odd.activeInWeek(9), isTrue);
      expect(odd.activeInWeek(11), isFalse);
      expect(course(type: WeekType.even).activeInWeek(2), isTrue);
    });
    test('冲突考虑周范围与单双周，包含节次边界', () {
      expect(
        course(type: WeekType.odd)
            .conflictsWith(course(id: '2', type: WeekType.even)),
        isFalse,
      );
      expect(course(end: 3).conflictsWith(course(id: '2', start: 4)), isFalse);
      expect(
        course().conflictsWith(course(id: '2', first: 2, last: 3)),
        isTrue,
      );
      expect(
        course().conflictsWith(course(id: '2', first: 3, last: 4)),
        isFalse,
      );
      expect(course().conflictsWith(course(id: '2', day: 7)), isFalse);
    });
    test('错误类型及逆序范围拒绝', () {
      expect(
        () => Course.fromJson({...course().toJson(), 'weekday': '1'}),
        throwsFormatException,
      );
      expect(() => course(first: 4, last: 2).validate(), throwsFormatException);
    });
    test('日期按自然日计算周数', () {
      final t = Timetable(
        id: 'main',
        name: '秋',
        startDate: DateTime(2026, 9, 7),
      );
      expect(t.currentWeek(DateTime(2026, 9, 13, 23, 59)), 1);
      expect(t.currentWeek(DateTime(2026, 9, 14)), 2);
    });
  });
  group('成绩', () {
    test('规格示例的加权平均为90', () {
      final c = GradeCalculator([grade('A', 95, 4), grade('B', 80, 2)]);
      expect(c.calculateWeightedAverage(), 90);
      expect(c.calculateAverage(), 87.5);
      expect(c.calculateTotalCredits(), 6);
      expect(c.calculatePassRate(), 100);
    });
    test('GPA排除开关、零学分与通过学分', () {
      final c = GradeCalculator([
        grade('A', 80, 2),
        grade('B', 95, 4, included: false),
        grade('C', 40, 1),
        grade('D', 100, 0),
      ]);
      expect(c.calculateGpa(), 2);
      expect(c.calculateTotalCredits(), 6);
      expect(c.calculatePassRate(), 75);
    });
    test('空集和零分母不产生NaN', () {
      final c = GradeCalculator([]);
      expect(c.calculateGpa(), 0);
      expect(c.calculateWeightedAverage(), 0);
      expect(c.calculatePassRate(), 0);
      expect(GradeCalculator([grade('A', 90, 0)]).hasGpaData, isFalse);
    });
    test('示例策略边界与分布', () {
      const s = ExampleFourPointStrategy();
      expect(s.scoreToGpa(59.9), 0);
      expect(s.scoreToGpa(60), 1);
      expect(s.scoreToGpa(90), 4);
      expect(s.scoreToGpa(100), 4);
      expect(
        GradeCalculator([grade('A', 89.9, 1), grade('B', 60, 1)])
            .distribution(),
        [0, 1, 0, 1, 0],
      );
      expect(() => grade('A', double.nan, 1).validate(), throwsFormatException);
    });
  });
  group('备份数据', () {
    test('往返保存稳定ID与多课表', () {
      final original = AppData.empty().copyWith(
        courses: [course()],
        grades: [grade('G', 85, 2)],
      );
      final restored = AppData.fromJson(
        objectOf(jsonDecode(jsonEncode(original.toJson()))),
      );
      expect(restored.courses.single.id, 'c1');
      expect(restored.grades.single.score, 85);
      expect(restored.selectedTimetableId, 'main');
    });
    test('版本、重复ID、悬空课表、设置拒绝', () {
      final j = AppData.empty().toJson();
      expect(
        () => AppData.fromJson({...j, 'version': 2}),
        throwsFormatException,
      );
      expect(
        () => AppData.fromJson({
          ...j,
          'courses': [course().toJson(), course().toJson()],
        }),
        throwsFormatException,
      );
      expect(
        () => AppData.fromJson({...j, 'selectedTimetableId': 'missing'}),
        throwsFormatException,
      );
      expect(
        () => AppSettings.fromJson({'theme': 'broken'}),
        throwsFormatException,
      );
    });
    test('非法日期和重叠时间拒绝', () {
      expect(
        () => Timetable.fromJson({
          'id': 'T',
          'name': 'T',
          'startDate': '2026-02-30',
        }),
        throwsFormatException,
      );
      expect(
        () => AppSettings.fromJson({
          'sectionTimes': [
            {'start': '08:00', 'end': '09:00'},
            {'start': '08:30', 'end': '09:30'},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
