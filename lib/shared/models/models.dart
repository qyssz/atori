import 'dart:math' as math;

typedef JsonMap = Map<String, dynamic>;

JsonMap objectOf(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('数据必须是 JSON 对象');
  }
  return value;
}

String textOf(JsonMap json, String key, {String? fallback}) {
  final value = json[key];
  if (value == null && fallback != null) return fallback;
  if (value is! String) throw FormatException('$key 必须是文本');
  return value;
}

int intOf(JsonMap json, String key, {int? fallback}) {
  final value = json[key];
  if (value == null && fallback != null) return fallback;
  if (value is! int) throw FormatException('$key 必须是整数');
  return value;
}

double numberOf(JsonMap json, String key, {double? fallback}) {
  final value = json[key];
  if (value == null && fallback != null) return fallback;
  if (value is! num || !value.isFinite) {
    throw FormatException('$key 必须是有效数字');
  }
  return value.toDouble();
}

bool boolOf(JsonMap json, String key, {bool? fallback}) {
  final value = json[key];
  if (value == null && fallback != null) return fallback;
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}

List<T> listOf<T>(JsonMap json, String key, T Function(JsonMap) decode) {
  final value = json[key];
  if (value is! List) throw FormatException('$key 必须是列表');
  if (value.length > 10000) throw FormatException('$key 记录过多');
  return value.map((entry) => decode(objectOf(entry))).toList();
}

enum WeekType { all, odd, even }

extension WeekTypeLabel on WeekType {
  String get label => switch (this) {
    WeekType.all => '每周',
    WeekType.odd => '单周',
    WeekType.even => '双周',
  };
}

class Course {
  const Course({
    required this.id,
    required this.name,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.startWeek,
    required this.endWeek,
    this.timetableId = 'main',
    this.teacher = '',
    this.location = '',
    this.weekType = WeekType.all,
    this.color = '#6C7CDB',
    this.note = '',
  });
  final String id, timetableId, name, teacher, location, color, note;
  final int weekday, startSection, endSection, startWeek, endWeek;
  final WeekType weekType;

  bool activeInWeek(int week) =>
      week >= startWeek &&
      week <= endWeek &&
      (weekType == WeekType.all ||
          (weekType == WeekType.odd && week.isOdd) ||
          (weekType == WeekType.even && week.isEven));

  bool conflictsWith(Course other) {
    if (timetableId != other.timetableId ||
        weekday != other.weekday ||
        endSection < other.startSection ||
        startSection > other.endSection) {
      return false;
    }
    for (
      var week = math.max(startWeek, other.startWeek);
      week <= math.min(endWeek, other.endWeek);
      week++
    ) {
      if (activeInWeek(week) && other.activeInWeek(week)) return true;
    }
    return false;
  }

  void validate() {
    if (id.trim().isEmpty || name.trim().isEmpty || timetableId.isEmpty) {
      throw const FormatException('课程名称、ID 和课表不能为空');
    }
    if (weekday < 1 ||
        weekday > 7 ||
        startSection < 1 ||
        endSection < startSection ||
        endSection > 24 ||
        startWeek < 1 ||
        endWeek < startWeek ||
        endWeek > 52) {
      throw const FormatException('课程星期、节次或教学周范围无效');
    }
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
      throw const FormatException('课程颜色须为 #RRGGBB');
    }
  }

  factory Course.fromJson(JsonMap j) {
    final type = textOf(j, 'weekType', fallback: 'all');
    if (!WeekType.values.any((e) => e.name == type)) {
      throw const FormatException('单双周类型无效');
    }
    final course = Course(
      id: textOf(j, 'id'),
      name: textOf(j, 'name'),
      timetableId: textOf(j, 'timetableId', fallback: 'main'),
      teacher: textOf(j, 'teacher', fallback: ''),
      location: textOf(j, 'location', fallback: ''),
      weekday: intOf(j, 'weekday'),
      startSection: intOf(j, 'startSection'),
      endSection: intOf(j, 'endSection'),
      startWeek: intOf(j, 'startWeek'),
      endWeek: intOf(j, 'endWeek'),
      weekType: WeekType.values.byName(type),
      color: textOf(j, 'color', fallback: '#6C7CDB'),
      note: textOf(j, 'note', fallback: ''),
    );
    course.validate();
    return course;
  }
  JsonMap toJson() => {
    'id': id,
    'timetableId': timetableId,
    'name': name,
    'teacher': teacher,
    'location': location,
    'weekday': weekday,
    'startSection': startSection,
    'endSection': endSection,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'weekType': weekType.name,
    'color': color,
    'note': note,
  };
}

class Grade {
  const Grade({
    required this.id,
    required this.courseName,
    required this.score,
    required this.credit,
    this.semester = '',
    this.courseType = '必修',
    this.includedInGpa = true,
  });
  final String id, courseName, semester, courseType;
  final double score, credit;
  final bool includedInGpa;
  void validate() {
    if (id.isEmpty ||
        courseName.trim().isEmpty ||
        !score.isFinite ||
        !credit.isFinite ||
        score < 0 ||
        score > 100 ||
        credit < 0 ||
        credit > 100) {
      throw const FormatException('成绩须为 0–100，学分须为 0–100，课程名称不能为空');
    }
  }

  factory Grade.fromJson(JsonMap j) {
    final grade = Grade(
      id: textOf(j, 'id'),
      courseName: textOf(j, 'courseName'),
      score: numberOf(j, 'score'),
      credit: numberOf(j, 'credit'),
      semester: textOf(j, 'semester', fallback: ''),
      courseType: textOf(j, 'courseType', fallback: '必修'),
      includedInGpa: boolOf(j, 'includedInGpa', fallback: true),
    );
    grade.validate();
    return grade;
  }
  JsonMap toJson() => {
    'id': id,
    'courseName': courseName,
    'score': score,
    'credit': credit,
    'semester': semester,
    'courseType': courseType,
    'includedInGpa': includedInGpa,
  };
}

class Timetable {
  const Timetable({
    required this.id,
    required this.name,
    this.startDate,
    this.weeks = 20,
  });
  final String id, name;
  final DateTime? startDate;
  final int weeks;
  int currentWeek(DateTime now) {
    if (startDate == null) return 1;
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );
    return ((today.difference(start).inDays / 7).floor() + 1).clamp(1, weeks);
  }

  factory Timetable.fromJson(JsonMap j) {
    final raw = j['startDate'];
    if (raw != null && raw is! String) throw const FormatException('开学日格式无效');
    final date = raw == null ? null : DateTime.tryParse(raw as String);
    if (raw != null &&
        (date == null ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw as String) ||
            dateString(date) != raw)) {
      throw const FormatException('开学日须为真实日期 YYYY-MM-DD');
    }
    final table = Timetable(
      id: textOf(j, 'id'),
      name: textOf(j, 'name'),
      weeks: intOf(j, 'weeks', fallback: 20),
      startDate: date,
    );
    if (table.id.isEmpty ||
        table.name.trim().isEmpty ||
        table.weeks < 1 ||
        table.weeks > 52) {
      throw const FormatException('课表名称或总周数无效');
    }
    if (date != null && date.weekday != DateTime.monday) {
      throw const FormatException('第一教学周须从周一开始');
    }
    return table;
  }
  JsonMap toJson() => {
    'id': id,
    'name': name,
    'weeks': weeks,
    'startDate': startDate == null ? null : dateString(startDate!),
  };
}

String dateString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SectionTime {
  const SectionTime(this.start, this.end);
  final String start, end;
  static int minutes(String time) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      throw const FormatException('上课时间须为 HH:mm');
    }
    final p = time.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  factory SectionTime.fromJson(JsonMap j) {
    final time = SectionTime(textOf(j, 'start'), textOf(j, 'end'));
    if (minutes(time.start) >= minutes(time.end)) {
      throw const FormatException('下课时间须晚于上课时间');
    }
    return time;
  }
  JsonMap toJson() => {'start': start, 'end': end};
}

class AppSettings {
  AppSettings({
    this.theme = 'system',
    this.seedColor = 0xFF5867D8,
    this.showTeacher = true,
    this.showLocation = true,
    this.cardRadius = 14,
    this.cardOpacity = 0.92,
    List<SectionTime>? sectionTimes,
  }) : sectionTimes = List.unmodifiable(
         sectionTimes ??
             List.generate(12, (i) {
               final start = 480 + i * 50;
               String fmt(int m) =>
                   '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
               return SectionTime(fmt(start), fmt(start + 45));
             }),
       );
  final String theme;
  final int seedColor;
  final bool showTeacher, showLocation;
  final double cardRadius, cardOpacity;
  final List<SectionTime> sectionTimes;
  AppSettings copyWith({
    String? theme,
    int? seedColor,
    bool? showTeacher,
    bool? showLocation,
    double? cardRadius,
    double? cardOpacity,
    List<SectionTime>? sectionTimes,
  }) => AppSettings(
    theme: theme ?? this.theme,
    seedColor: seedColor ?? this.seedColor,
    showTeacher: showTeacher ?? this.showTeacher,
    showLocation: showLocation ?? this.showLocation,
    cardRadius: cardRadius ?? this.cardRadius,
    cardOpacity: cardOpacity ?? this.cardOpacity,
    sectionTimes: sectionTimes ?? this.sectionTimes,
  );
  factory AppSettings.fromJson(JsonMap j) {
    final settings = AppSettings(
      theme: textOf(j, 'theme', fallback: 'system'),
      seedColor: intOf(j, 'seedColor', fallback: 0xFF5867D8),
      showTeacher: boolOf(j, 'showTeacher', fallback: true),
      showLocation: boolOf(j, 'showLocation', fallback: true),
      cardRadius: numberOf(j, 'cardRadius', fallback: 14),
      cardOpacity: numberOf(j, 'cardOpacity', fallback: 0.92),
      sectionTimes: j.containsKey('sectionTimes')
          ? listOf(j, 'sectionTimes', SectionTime.fromJson)
          : null,
    );
    if (!['system', 'light', 'dark'].contains(settings.theme) ||
        settings.sectionTimes.isEmpty ||
        settings.sectionTimes.length > 24 ||
        settings.cardRadius < 0 ||
        settings.cardRadius > 32 ||
        settings.cardOpacity < 0.3 ||
        settings.cardOpacity > 1 ||
        settings.seedColor < 0xFF000000 ||
        settings.seedColor > 0xFFFFFFFF) {
      throw const FormatException('外观或课表设置无效');
    }
    for (var i = 1; i < settings.sectionTimes.length; i++) {
      if (SectionTime.minutes(settings.sectionTimes[i].start) <
          SectionTime.minutes(settings.sectionTimes[i - 1].end)) {
        throw const FormatException('各节上课时间须按顺序排列且不重叠');
      }
    }
    return settings;
  }
  JsonMap toJson() => {
    'theme': theme,
    'seedColor': seedColor,
    'showTeacher': showTeacher,
    'showLocation': showLocation,
    'cardRadius': cardRadius,
    'cardOpacity': cardOpacity,
    'sectionTimes': sectionTimes.map((s) => s.toJson()).toList(),
  };
}

enum ActivityStatus { available, registered, completed, ended }

enum VolunteerStatus { available, registered, ongoing, completed, ended }

class SecondClassActivity {
  const SecondClassActivity({
    required this.id,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.status,
    this.score = 0,
    this.description = '',
    this.organizer = '',
    this.registrationStart,
    this.registrationEnd,
  });
  final String id, title, category, location, description, organizer;
  final DateTime startTime, endTime;
  final DateTime? registrationStart, registrationEnd;
  final ActivityStatus status;
  final double score;
  factory SecondClassActivity.fromJson(JsonMap j) {
    final dates = activityDates(j);
    DateTime? registrationDate(String key) {
      if (j[key] == null) return null;
      final value = DateTime.tryParse(textOf(j, key));
      if (value == null) throw const FormatException('报名时间格式无效');
      return value;
    }

    final registrationStart = registrationDate('registrationStart');
    final registrationEnd = registrationDate('registrationEnd');
    if ((registrationStart == null) != (registrationEnd == null) ||
        (registrationStart != null &&
            registrationEnd!.isBefore(registrationStart))) {
      throw const FormatException('报名起止时间须完整且顺序正确');
    }
    final status = textOf(j, 'status');
    if (!ActivityStatus.values.any((s) => s.name == status)) {
      throw const FormatException('活动状态无效');
    }
    return SecondClassActivity(
      id: textOf(j, 'id'),
      title: textOf(j, 'title'),
      category: textOf(j, 'category'),
      startTime: dates.$1,
      endTime: dates.$2,
      location: textOf(j, 'location'),
      status: ActivityStatus.values.byName(status),
      score: positiveNumber(j, 'score'),
      organizer: textOf(j, 'organizer', fallback: ''),
      registrationStart: registrationStart,
      registrationEnd: registrationEnd,
      description: textOf(j, 'description', fallback: ''),
    );
  }
  JsonMap toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'location': location,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'status': status.name,
    'score': score,
    'description': description,
    'organizer': organizer,
    'registrationStart': registrationStart?.toIso8601String(),
    'registrationEnd': registrationEnd?.toIso8601String(),
  };
}

class VolunteerActivity {
  const VolunteerActivity({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.hours,
    required this.status,
    this.description = '',
  });
  final String id, title, location, description;
  final DateTime startTime, endTime;
  final double hours;
  final VolunteerStatus status;
  factory VolunteerActivity.fromJson(JsonMap j) {
    final dates = activityDates(j);
    final status = textOf(j, 'status');
    if (!VolunteerStatus.values.any((s) => s.name == status)) {
      throw const FormatException('志愿状态无效');
    }
    return VolunteerActivity(
      id: textOf(j, 'id'),
      title: textOf(j, 'title'),
      startTime: dates.$1,
      endTime: dates.$2,
      location: textOf(j, 'location'),
      hours: positiveNumber(j, 'hours'),
      status: VolunteerStatus.values.byName(status),
      description: textOf(j, 'description', fallback: ''),
    );
  }
  JsonMap toJson() => {
    'id': id,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'location': location,
    'hours': hours,
    'status': status.name,
    'description': description,
  };
}

(DateTime, DateTime) activityDates(JsonMap j) {
  final start = DateTime.tryParse(textOf(j, 'startTime'));
  final end = DateTime.tryParse(textOf(j, 'endTime'));
  if (start == null ||
      end == null ||
      end.isBefore(start) ||
      textOf(j, 'id').isEmpty ||
      textOf(j, 'title').trim().isEmpty) {
    throw const FormatException('活动日期、名称或 ID 无效');
  }
  return (start, end);
}

double positiveNumber(JsonMap j, String key) {
  final value = numberOf(j, key, fallback: 0);
  if (value < 0) throw FormatException('$key 不能为负数');
  return value;
}

class AppData {
  AppData({
    required List<Timetable> timetables,
    required this.selectedTimetableId,
    List<Course> courses = const [],
    List<Grade> grades = const [],
    List<SecondClassActivity> secondClass = const [],
    List<VolunteerActivity> volunteer = const [],
    AppSettings? settings,
  }) : timetables = List.unmodifiable(timetables),
       courses = List.unmodifiable(courses),
       grades = List.unmodifiable(grades),
       secondClass = List.unmodifiable(secondClass),
       volunteer = List.unmodifiable(volunteer),
       settings = settings ?? AppSettings();
  final List<Timetable> timetables;
  final String selectedTimetableId;
  final List<Course> courses;
  final List<Grade> grades;
  final List<SecondClassActivity> secondClass;
  final List<VolunteerActivity> volunteer;
  final AppSettings settings;
  Timetable get timetable =>
      timetables.firstWhere((t) => t.id == selectedTimetableId);
  factory AppData.empty() => AppData(
    timetables: [const Timetable(id: 'main', name: '我的课表')],
    selectedTimetableId: 'main',
  );
  AppData copyWith({
    List<Timetable>? timetables,
    String? selectedTimetableId,
    List<Course>? courses,
    List<Grade>? grades,
    List<SecondClassActivity>? secondClass,
    List<VolunteerActivity>? volunteer,
    AppSettings? settings,
  }) => AppData(
    timetables: timetables ?? this.timetables,
    selectedTimetableId: selectedTimetableId ?? this.selectedTimetableId,
    courses: courses ?? this.courses,
    grades: grades ?? this.grades,
    secondClass: secondClass ?? this.secondClass,
    volunteer: volunteer ?? this.volunteer,
    settings: settings ?? this.settings,
  );
  factory AppData.fromJson(JsonMap j) {
    if (intOf(j, 'version') != 1) throw const FormatException('不支持此备份版本');
    final data = AppData(
      timetables: listOf(j, 'timetables', Timetable.fromJson),
      selectedTimetableId: textOf(j, 'selectedTimetableId'),
      courses: listOf(j, 'courses', Course.fromJson),
      grades: listOf(j, 'grades', Grade.fromJson),
      secondClass: listOf(j, 'secondClass', SecondClassActivity.fromJson),
      volunteer: listOf(j, 'volunteer', VolunteerActivity.fromJson),
      settings: AppSettings.fromJson(objectOf(j['settings'])),
    );
    data.validate();
    return data;
  }
  void validate() {
    void unique(Iterable<String> ids) {
      final list = ids.toList();
      if (list.any((id) => id.isEmpty) || list.toSet().length != list.length) {
        throw const FormatException('记录 ID 为空或重复');
      }
    }

    if (timetables.isEmpty ||
        !timetables.any((t) => t.id == selectedTimetableId)) {
      throw const FormatException('当前课表不存在');
    }
    unique(timetables.map((t) => t.id));
    unique(courses.map((c) => c.id));
    unique(grades.map((g) => g.id));
    unique(secondClass.map((a) => a.id));
    unique(volunteer.map((a) => a.id));
    AppSettings.fromJson(settings.toJson());
    for (final t in timetables) {
      Timetable.fromJson(t.toJson());
    }
    for (final course in courses) {
      course.validate();
      final table = timetables
          .where((t) => t.id == course.timetableId)
          .firstOrNull;
      if (table == null ||
          course.endWeek > table.weeks ||
          course.endSection > settings.sectionTimes.length) {
        throw const FormatException('课程引用无效课表，或超出总周数/节次数量');
      }
    }
    for (final grade in grades) {
      grade.validate();
    }
    for (final a in secondClass) {
      SecondClassActivity.fromJson(a.toJson());
    }
    for (final a in volunteer) {
      VolunteerActivity.fromJson(a.toJson());
    }
  }

  JsonMap toJson() => {
    'version': 1,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'timetables': timetables.map((t) => t.toJson()).toList(),
    'selectedTimetableId': selectedTimetableId,
    'courses': courses.map((c) => c.toJson()).toList(),
    'grades': grades.map((g) => g.toJson()).toList(),
    'secondClass': secondClass.map((a) => a.toJson()).toList(),
    'volunteer': volunteer.map((a) => a.toJson()).toList(),
    'settings': settings.toJson(),
  };
}
