import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../shared/models/models.dart';

String prettyJson(Object value) =>
    const JsonEncoder.withIndent('  ').convert(value);
String csvEncode(List<List<Object?>> rows) =>
    '\uFEFF${rows.map((row) => row.map((v) => '"${(v ?? '').toString().replaceAll('"', '""')}"').join(',')).join('\r\n')}\r\n';

List<List<String>> csvDecode(String input) {
  final text = input.replaceFirst(RegExp(r'^\uFEFF'), '');
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  bool quoted = false, closed = false;
  void endField() {
    row.add(field.toString());
    field = StringBuffer();
    closed = false;
  }

  void endRow() {
    endField();
    if (row.any((s) => s.isNotEmpty)) {
      rows.add(row);
    }
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == ',') {
      endField();
    } else if (c == '\n' || c == '\r') {
      endRow();
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
        i++;
      }
    } else if (c == '"' && field.isEmpty && !closed) {
      quoted = true;
    } else {
      if (closed || c == '"') {
        throw const FormatException('CSV 引号或字段格式不正确');
      }
      field.write(c);
    }
  }
  if (quoted) {
    throw const FormatException('CSV 存在未闭合的引号');
  }
  if (field.isNotEmpty || row.isNotEmpty || closed) {
    endRow();
  }
  if (rows.length > 10001) {
    throw const FormatException('导入记录过多');
  }
  return rows;
}

List<Map<String, String>> csvRecords(
  String text,
  List<String> requiredHeaders,
) {
  final rows = csvDecode(text);
  if (rows.isEmpty) {
    throw const FormatException('CSV 文件为空');
  }
  final header = rows.first.map((s) => s.trim()).toList();
  if (header.toSet().length != header.length ||
      !requiredHeaders.every(header.contains)) {
    throw FormatException('CSV 缺少必需列：${requiredHeaders.join('、')}');
  }
  return rows.skip(1).map((row) {
    if (row.length != header.length) {
      throw const FormatException('CSV 每行列数须与表头一致');
    }
    return Map.fromIterables(header, row);
  }).toList();
}

abstract interface class TimetableImporter {
  Future<List<Course>> importCourses();
}

List<dynamic> jsonRecords(String text, String key) {
  final raw = jsonDecode(text.replaceFirst(RegExp(r'^\uFEFF'), ''));
  if (raw is List) {
    return raw;
  }
  final j = objectOf(raw);
  if (j.containsKey('version') && intOf(j, 'version') != 1) {
    throw const FormatException('不支持此文件版本');
  }
  if (j[key] is! List) {
    throw const FormatException('导入文件缺少记录列表');
  }
  return j[key] as List;
}

class JsonImporter implements TimetableImporter {
  const JsonImporter(this.text, this.timetableId);
  final String text, timetableId;
  @override
  Future<List<Course>> importCourses() async {
    final rows = jsonRecords(text, 'courses');
    if (rows.length > 10000) {
      throw const FormatException('导入课程过多');
    }
    return rows
        .map(
          (r) => Course.fromJson({
            ...objectOf(r),
            'id': const Uuid().v4(),
            'timetableId': timetableId,
          }),
        )
        .toList();
  }
}

class CsvImporter implements TimetableImporter {
  const CsvImporter(this.text, this.timetableId);
  final String text, timetableId;
  @override
  Future<List<Course>> importCourses() async =>
      csvRecords(text, [
        'name',
        'weekday',
        'startSection',
        'endSection',
        'startWeek',
        'endWeek',
      ]).map((row) {
        int integer(String key) {
          final n = int.tryParse(row[key] ?? '');
          if (n == null) {
            throw FormatException('CSV 的 $key 须为整数');
          }
          return n;
        }

        return Course.fromJson({
          'id': const Uuid().v4(),
          'timetableId': timetableId,
          'name': row['name'],
          'weekday': integer('weekday'),
          'startSection': integer('startSection'),
          'endSection': integer('endSection'),
          'startWeek': integer('startWeek'),
          'endWeek': integer('endWeek'),
          'teacher': row['teacher'] ?? '',
          'location': row['location'] ?? '',
          'note': row['note'] ?? '',
          'weekType': (row['weekType'] ?? '').isEmpty ? 'all' : row['weekType'],
          'color': (row['color'] ?? '').isEmpty ? '#6C7CDB' : row['color'],
        });
      }).toList();
}

String coursesCsv(List<Course> courses) => csvEncode([
  [
    'name',
    'teacher',
    'location',
    'weekday',
    'startSection',
    'endSection',
    'startWeek',
    'endWeek',
    'weekType',
    'color',
    'note',
  ],
  ...courses.map(
    (c) => [
      c.name,
      c.teacher,
      c.location,
      c.weekday,
      c.startSection,
      c.endSection,
      c.startWeek,
      c.endWeek,
      c.weekType.name,
      c.color,
      c.note,
    ],
  ),
]);
String gradesCsv(List<Grade> grades) => csvEncode([
  ['courseName', 'score', 'credit', 'semester', 'courseType', 'includedInGpa'],
  ...grades.map(
    (g) => [
      g.courseName,
      g.score,
      g.credit,
      g.semester,
      g.courseType,
      g.includedInGpa,
    ],
  ),
]);

List<Grade> parseGrades(String text, {bool csv = false}) {
  if (!csv) {
    return jsonRecords(text, 'grades')
        .map((r) => Grade.fromJson({...objectOf(r), 'id': const Uuid().v4()}))
        .toList();
  }
  return csvRecords(text, ['courseName', 'score', 'credit']).map((r) {
    final included = r['includedInGpa'] ?? 'true';
    if (!['true', 'false'].contains(included)) {
      throw const FormatException('includedInGpa 须为 true 或 false');
    }
    return Grade.fromJson({
      'id': const Uuid().v4(),
      'courseName': r['courseName'],
      'score': double.tryParse(r['score'] ?? ''),
      'credit': double.tryParse(r['credit'] ?? ''),
      'semester': r['semester'] ?? '',
      'courseType': r['courseType'] ?? '必修',
      'includedInGpa': included == 'true',
    });
  }).toList();
}

String _icsEscape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\n', r'\n')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');
String _utc(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}T${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}Z';
String _fold(String line) {
  final out = StringBuffer();
  var count = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final length = utf8.encode(char).length;
    if (count + length > 75) {
      out.write('\r\n ');
      count = 1;
    }
    out.write(char);
    count += length;
  }
  return out.toString();
}

String exportIcs(
  Timetable table,
  List<Course> courses,
  AppSettings settings, {
  DateTime? now,
}) {
  if (table.startDate == null) {
    throw const FormatException('请先设置第一教学周的周一和上课时间');
  }
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Atori//Campus Timetable//ZH',
    'CALSCALE:GREGORIAN',
    'X-WR-CALNAME:${_icsEscape(table.name)}',
  ];
  for (final c in courses.where((c) => c.timetableId == table.id)) {
    c.validate();
    if (c.endSection > settings.sectionTimes.length ||
        c.endWeek > table.weeks) {
      throw const FormatException('课程超出课表范围');
    }
    for (var week = c.startWeek; week <= c.endWeek; week++) {
      if (!c.activeInWeek(week)) {
        continue;
      }
      final day = table.startDate!.add(
        Duration(days: (week - 1) * 7 + c.weekday - 1),
      );
      DateTime instant(String time) {
        final m = SectionTime.minutes(time);
        return DateTime.utc(
          day.year,
          day.month,
          day.day,
          m ~/ 60,
          m % 60,
        ).subtract(const Duration(hours: 8));
      }

      final id = base64Url.encode(utf8.encode(c.id)).replaceAll('=', '');
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:$id-$week@atori.local',
        'DTSTAMP:${_utc((now ?? DateTime.now()).toUtc())}',
        'DTSTART:${_utc(instant(settings.sectionTimes[c.startSection - 1].start))}',
        'DTEND:${_utc(instant(settings.sectionTimes[c.endSection - 1].end))}',
        'SUMMARY:${_icsEscape(c.name)}',
        'LOCATION:${_icsEscape(c.location)}',
        'DESCRIPTION:${_icsEscape('${c.teacher}\n${c.note}')}',
        'END:VEVENT',
      ]);
    }
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(_fold).join('\r\n')}\r\n';
}
