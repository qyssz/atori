import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:atori/core/utils/data_exchange.dart';
import 'package:atori/shared/models/models.dart';

void main() {
  const c = Course(
    id: 'c\ninject',
    name: '数学,"专题"\n换行',
    weekday: 1,
    startSection: 1,
    endSection: 2,
    startWeek: 1,
    endWeek: 3,
    weekType: WeekType.odd,
    note: '示例;备注',
  );
  test('CSV 中文、逗号、引号、换行往返', () async {
    final courses = await CsvImporter(coursesCsv([c]), 'main').importCourses();
    expect(courses.single.name, c.name);
    expect(courses.single.note, c.note);
    expect(courses.single.weekType, WeekType.odd);
    expect(() => csvDecode('name\r\n"未闭合'), throwsFormatException);
    expect(() => csvDecode('"a"x'), throwsFormatException);
  });
  test('JSON 课程导入生成新ID且归入所选课表', () async {
    final entries = await JsonImporter(
      jsonEncode([c.toJson()]),
      'other',
    ).importCourses();
    expect(entries.single.timetableId, 'other');
    expect(entries.single.id, isNot(c.id));
    await expectLater(
      JsonImporter('{"version":2,"courses":[]}', 'main').importCourses(),
      throwsFormatException,
    );
  });
  test('成绩CSV往返，并拒绝无效布尔值', () {
    const g = Grade(
      id: 'G',
      courseName: '测试,科目',
      score: 90,
      credit: 2,
      includedInGpa: false,
    );
    final grades = parseGrades(gradesCsv([g]), csv: true);
    expect(grades.single.courseName, g.courseName);
    expect(grades.single.includedInGpa, isFalse);
    expect(
      () => parseGrades(
        'courseName,score,credit,includedInGpa\nA,90,2,yes',
        csv: true,
      ),
      throwsFormatException,
    );
  });
  test('ICS 按单双周导出、UTC时间、转义和注入保护', () {
    final table = Timetable(
      id: 'main',
      name: '秋季',
      startDate: DateTime(2026, 10, 5),
    );
    final text = exportIcs(
      table,
      [c],
      AppSettings(),
      now: DateTime.utc(2026, 10, 9),
    );
    expect('BEGIN:VEVENT'.allMatches(text).length, 2);
    expect(text, contains('DTSTART:20261005T000000Z'));
    expect(text, contains('DTSTART:20261019T000000Z'));
    expect(text, contains(r'SUMMARY:数学\,"专题"\n换行'));
    expect(text, contains(r'示例\;备注'));
    expect(text, isNot(contains('UID:c\ninject')));
    expect(
      () => exportIcs(const Timetable(id: 'main', name: '未配置'), [
        c,
      ], AppSettings()),
      throwsFormatException,
    );
  });
  test('ICS 中文长行按UTF-8字节折行', () {
    final long = Course.fromJson({...c.toJson(), 'name': '很长的课程名称' * 30});
    final text = exportIcs(
      Timetable(id: 'main', name: '秋季', startDate: DateTime(2026, 10, 5)),
      [long],
      AppSettings(),
    );
    expect(
      text.split('\r\n').every((line) => utf8.encode(line).length <= 75),
      isTrue,
    );
  });
}
