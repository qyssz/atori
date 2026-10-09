import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_controller.dart';
import '../../../core/utils/data_exchange.dart';
import '../../../shared/models/models.dart';

class FileDataSource {
  const FileDataSource();
  Future<(String, String)?> read(List<String> extensions) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) {
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (builder.length + chunk.length > 20 * 1024 * 1024) {
        throw const FormatException('文件不能超过 20 MB');
      }
      builder.add(chunk);
    }
    return (file.name, utf8.decode(builder.takeBytes()));
  }

  Future<bool> write(String name, String text, String mime) async =>
      await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: mime,
      ) !=
      null;
}

final exchangeProvider = Provider((ref) => ExchangeController(ref));

class ExchangeController {
  ExchangeController(this.ref, {this.files = const FileDataSource()});
  final Ref ref;
  final FileDataSource files;
  Future<List<Course>?> pickCourses() async {
    final file = await files.read(['json', 'csv']);
    if (file == null) {
      return null;
    }
    final id = ref.read(appControllerProvider).selectedTimetableId;
    final TimetableImporter importer = file.$1.toLowerCase().endsWith('.csv')
        ? CsvImporter(file.$2, id)
        : JsonImporter(file.$2, id);
    final courses = await importer.importCourses();
    final current = ref.read(appControllerProvider);
    current.copyWith(courses: [...current.courses, ...courses]).validate();
    return courses;
  }

  Future<List<Grade>?> pickGrades() async {
    final file = await files.read(['json', 'csv']);
    if (file == null) {
      return null;
    }
    return parseGrades(file.$2, csv: file.$1.toLowerCase().endsWith('.csv'));
  }

  Future<AppData?> pickBackup() async {
    final file = await files.read(['json']);
    if (file == null) {
      return null;
    }
    return AppData.fromJson(
      objectOf(jsonDecode(file.$2.replaceFirst(RegExp(r'^\uFEFF'), ''))),
    );
  }

  Future<bool> export(String kind) async {
    final data = ref.read(appControllerProvider);
    final courses = data.courses
        .where((c) => c.timetableId == data.selectedTimetableId)
        .toList();
    final (name, text, mime) = switch (kind) {
      'backup' => (
        'atori-backup.json',
        prettyJson(data.toJson()),
        'application/json',
      ),
      'courses-json' => (
        'atori-timetable.json',
        prettyJson({
          'version': 1,
          'timetable': data.timetable.toJson(),
          'courses': courses.map((c) => c.toJson()).toList(),
        }),
        'application/json',
      ),
      'courses-csv' => ('atori-timetable.csv', coursesCsv(courses), 'text/csv'),
      'ics' => (
        'atori-timetable.ics',
        exportIcs(data.timetable, courses, data.settings),
        'text/calendar',
      ),
      'grades-json' => (
        'atori-grades.json',
        prettyJson({
          'version': 1,
          'grades': data.grades.map((g) => g.toJson()).toList(),
        }),
        'application/json',
      ),
      'grades-csv' => ('atori-grades.csv', gradesCsv(data.grades), 'text/csv'),
      _ => throw const FormatException('不支持的导出格式'),
    };
    return files.write(name, text, mime);
  }
}
