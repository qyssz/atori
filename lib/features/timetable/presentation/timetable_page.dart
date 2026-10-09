import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_controller.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});
  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  String? _tableId;
  int _week = 1;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider);
    final table = data.timetable;
    if (_tableId != table.id) {
      _tableId = table.id;
      _week = table.currentWeek(DateTime.now());
    }
    _week = _week.clamp(1, table.weeks);
    final courses = data.courses
        .where((c) => c.timetableId == table.id && c.activeInWeek(_week))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 24),
            SizedBox(width: 10),
            Text('亚托莉'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '课表设置',
            onPressed: () => _editTable(table),
            icon: const Icon(Icons.tune),
          ),
          PopupMenuButton<String>(
            tooltip: '课表管理',
            onSelected: (value) async {
              if (value == 'new') {
                await _editTable(null);
              }
              if (value == 'data' && context.mounted) {
                context.push('/data');
              }
              if (value == 'delete' &&
                  context.mounted &&
                  await confirm(
                    context,
                    '删除课表？',
                    '这会删除这份课表及其课程。',
                    button: '删除',
                  )) {
                if (context.mounted) {
                  await perform(
                    context,
                    () => ref
                        .read(appControllerProvider.notifier)
                        .deleteTimetable(table.id),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new', child: Text('新建课表')),
              const PopupMenuItem(value: 'data', child: Text('导入与导出')),
              if (data.timetables.length > 1)
                const PopupMenuItem(value: 'delete', child: Text('删除当前课表')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_course'),
        onPressed: () => context.push('/course/edit/new'),
        icon: const Icon(Icons.add),
        label: const Text('添加课程'),
      ),
      body: Column(
        children: [
          PageHeading(
            '一周，尽在掌握',
            DateFormat('M 月 d 日 · EEEE', 'zh_CN').format(DateTime.now()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: table.id,
                      items: data.timetables
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                t.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id != null) {
                          perform(
                            context,
                            () => ref
                                .read(appControllerProvider.notifier)
                                .selectTimetable(id),
                          );
                        }
                      },
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _editTable(table),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    table.startDate == null ? '设置学期' : '${table.weeks} 周',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 16, 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('previous_week'),
                  tooltip: '上一周',
                  onPressed: _week > 1 ? () => setState(() => _week--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '第 $_week 周',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  key: const Key('next_week'),
                  tooltip: '下一周',
                  onPressed: _week < table.weeks
                      ? () => setState(() => _week++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(
                      () => _week = table.currentWeek(DateTime.now()),
                    ),
                    child: Text(
                      table.startDate == null ? '回到第 1 周' : '回到本周',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (table.startDate == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '设置第一教学周的周一后，可计算当前周。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: courses.isEmpty
                ? EmptyState(
                    '这周没有课程',
                    '添加课程，或切换到其他教学周。',
                    icon: Icons.event_available,
                    action: TextButton(
                      onPressed: () => context.push('/course/edit/new'),
                      child: const Text('添加第一门课程'),
                    ),
                  )
                : _WeekGrid(
                    courses: courses,
                    settings: data.settings,
                    table: table,
                    week: _week,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTable(Timetable? table) async {
    final result = await editTimetable(context, table);
    if (result != null && mounted) {
      await perform(
        context,
        () => ref.read(appControllerProvider.notifier).saveTimetable(result),
      );
    }
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.courses,
    required this.settings,
    required this.table,
    required this.week,
  });
  final List<Course> courses;
  final AppSettings settings;
  final Timetable table;
  final int week;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const rowHeight = 68.0;
      var maximumLanes = 1;
      for (var day = 1; day <= 7; day++) {
        final entries = courses.where((c) => c.weekday == day).toList()
          ..sort((a, b) => a.startSection.compareTo(b.startSection));
        final ends = <int>[];
        for (final course in entries) {
          final lane = ends.indexWhere((end) => end < course.startSection);
          if (lane < 0) {
            ends.add(course.endSection);
          } else {
            ends[lane] = course.endSection;
          }
        }
        maximumLanes = math.max(maximumLanes, ends.length);
      }
      // Keep overlapping courses readable and reachable by horizontal scrolling.
      final gridWidth = math.max(
        constraints.maxWidth,
        math.max(690.0, 44.0 + 7 * maximumLanes * 80),
      );
      final dayWidth = (gridWidth - 44) / 7;
      final height = settings.sectionTimes.length * rowHeight;
      final start = table.startDate?.add(Duration(days: (week - 1) * 7));
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: gridWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 88),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 44),
                    ...List.generate(
                      7,
                      (i) => SizedBox(
                        width: dayWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            children: [
                              Text(
                                '周${['一', '二', '三', '四', '五', '六', '日'][i]}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              if (start != null)
                                Text(
                                  DateFormat('M/d')
                                      .format(start.add(Duration(days: i))),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Column(
                        children: List.generate(
                          settings.sectionTimes.length,
                          (i) => SizedBox(
                            height: rowHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${i + 1}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(
                                  settings.sectionTimes[i].start,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...List.generate(7, (i) {
                      final entries =
                          courses.where((c) => c.weekday == i + 1).toList()
                            ..sort(
                              (a, b) =>
                                  a.startSection.compareTo(b.startSection),
                            );
                      final lanes = <String, int>{};
                      final ends = <int>[];
                      for (final c in entries) {
                        var lane = ends.indexWhere(
                          (end) => end < c.startSection,
                        );
                        if (lane < 0) {
                          lane = ends.length;
                          ends.add(0);
                        }
                        ends[lane] = c.endSection;
                        lanes[c.id] = lane;
                      }
                      final laneWidth = dayWidth / math.max(1, ends.length);
                      return SizedBox(
                        width: dayWidth,
                        height: height,
                        child: Stack(
                          children: [
                            ...List.generate(
                              settings.sectionTimes.length,
                              (s) => Positioned(
                                top: s * rowHeight,
                                left: 0,
                                right: 0,
                                height: rowHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context).dividerColor
                                            .withValues(alpha: 0.15),
                                      ),
                                      left: BorderSide(
                                        color: Theme.of(context).dividerColor
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ...entries.map(
                              (c) => Positioned(
                                top: (c.startSection - 1) * rowHeight + 3,
                                left: lanes[c.id]! * laneWidth + 3,
                                width: laneWidth - 6,
                                height:
                                    (c.endSection - c.startSection + 1) *
                                        rowHeight -
                                    6,
                                child: _CourseCard(
                                  course: c,
                                  settings: settings,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.settings});
  final Course course;
  final AppSettings settings;
  @override
  Widget build(BuildContext context) => Material(
    color: courseColor(course.color).withValues(alpha: settings.cardOpacity),
    borderRadius: BorderRadius.circular(settings.cardRadius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () =>
          context.push('/course/detail/${Uri.encodeComponent(course.id)}'),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (constraints.maxHeight > 65 &&
                  settings.showLocation &&
                  course.location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  course.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
              if (constraints.maxHeight > 105 &&
                  settings.showTeacher &&
                  course.teacher.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  course.teacher,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
              if (constraints.maxHeight > 65) ...[
                const Spacer(),
                Text(
                  '${course.startSection}–${course.endSection} 节',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Future<Timetable?> editTimetable(
  BuildContext context,
  Timetable? existing,
) async {
  final name = TextEditingController(text: existing?.name ?? '新课表');
  final weeks = TextEditingController(text: '${existing?.weeks ?? 20}');
  final date = TextEditingController(
    text: existing?.startDate == null ? '' : dateString(existing!.startDate!),
  );
  final form = GlobalKey<FormState>();
  final result = await showDialog<Timetable>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? '新建课表' : '学期设置'),
        scrollable: true,
        content: SizedBox(
          width: 380,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '课表名称'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入名称' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: weeks,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '总教学周数（1–52）'),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ||
                          int.parse(v!) < 1 ||
                          int.parse(v) > 52
                      ? '请输入 1–52'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: date,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: '第一教学周的周一',
                    hintText: '可稍后配置',
                    suffixIcon: IconButton(
                      tooltip: '清除日期',
                      onPressed: () => setState(() => date.clear()),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  onTap: () async {
                    final initial =
                        DateTime.tryParse(date.text) ?? DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(math.min(2000, initial.year)),
                      lastDate: DateTime(math.max(2100, initial.year), 12, 31),
                    );
                    if (picked != null) {
                      setState(() => date.text = dateString(picked));
                    }
                  },
                  validator: (v) =>
                      v != null &&
                          v.isNotEmpty &&
                          DateTime.tryParse(v)?.weekday != DateTime.monday
                      ? '请选择教学周的周一'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  Timetable(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name.text.trim(),
                    weeks: int.parse(weeks.text),
                    startDate: date.text.isEmpty
                        ? null
                        : DateTime.parse(date.text),
                  ),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  weeks.dispose();
  date.dispose();
  return result;
}

class CourseEditorPage extends ConsumerStatefulWidget {
  const CourseEditorPage(this.id, {super.key});
  final String id;
  @override
  ConsumerState<CourseEditorPage> createState() => _CourseEditorPageState();
}

class _CourseEditorPageState extends ConsumerState<CourseEditorPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  Course? _course;
  late String _tableId, _color;
  int _weekday = 1;
  WeekType _type = WeekType.all;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final data = ref.read(appControllerProvider);
    _course = data.courses.where((c) => c.id == widget.id).firstOrNull;
    _tableId = _course?.timetableId ?? data.selectedTimetableId;
    _color = _course?.color ?? coursePalette.first;
    _weekday = _course?.weekday ?? 1;
    _type = _course?.weekType ?? WeekType.all;
    final values = {
      'name': _course?.name ?? '',
      'teacher': _course?.teacher ?? '',
      'location': _course?.location ?? '',
      'first': '${_course?.startSection ?? 1}',
      'last': '${_course?.endSection ?? 2}',
      'start': '${_course?.startWeek ?? 1}',
      'end': '${_course?.endWeek ?? data.timetable.weeks}',
      'note': _course?.note ?? '',
    };
    for (final e in values.entries) {
      _fields[e.key] = TextEditingController(text: e.value);
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    bool number = false,
    bool required = false,
  }) => TextFormField(
    key: Key('course_$key'),
    controller: _fields[key],
    decoration: InputDecoration(labelText: label),
    keyboardType: number ? TextInputType.number : TextInputType.text,
    maxLines: key == 'note' ? 3 : 1,
    validator: (v) => required && (v == null || v.trim().isEmpty)
        ? '请填写$label'
        : number && int.tryParse(v ?? '') == null
        ? '请输入整数'
        : null,
  );
  @override
  Widget build(BuildContext context) {
    if (widget.id != 'new' && _course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('课程已不存在')),
        body: const EmptyState('未找到课程', '课程可能已删除，请返回课表。'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_course == null ? '添加课程' : '编辑课程')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            children: [
              _field('name', '课程名称', required: true),
              const SizedBox(height: 16),
              _field('teacher', '教师'),
              const SizedBox(height: 16),
              _field('location', '教室 / 地点'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: '星期'),
                items: List.generate(
                  7,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('星期${['一', '二', '三', '四', '五', '六', '日'][i]}'),
                  ),
                ),
                onChanged: (v) => setState(() => _weekday = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _field('first', '开始节次', number: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('last', '结束节次', number: true)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _field('start', '开始周', number: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('end', '结束周', number: true)),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WeekType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '单双周'),
                items: WeekType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: coursePalette
                    .map(
                      (color) => IconButton(
                        tooltip: '课程颜色 $color',
                        onPressed: () => setState(() => _color = color),
                        style: IconButton.styleFrom(
                          backgroundColor: courseColor(color),
                        ),
                        icon: Icon(
                          _color == color ? Icons.check : Icons.circle,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _field('note', '备注'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('course_save'),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? '正在保存…' : '保存课程'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final c = Course(
      id: _course?.id ?? const Uuid().v4(),
      timetableId: _tableId,
      name: _fields['name']!.text.trim(),
      teacher: _fields['teacher']!.text.trim(),
      location: _fields['location']!.text.trim(),
      weekday: _weekday,
      startSection: int.parse(_fields['first']!.text),
      endSection: int.parse(_fields['last']!.text),
      startWeek: int.parse(_fields['start']!.text),
      endWeek: int.parse(_fields['end']!.text),
      weekType: _type,
      color: _color,
      note: _fields['note']!.text,
    );
    try {
      c.validate();
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    final overlaps = ref
        .read(appControllerProvider)
        .courses
        .where((other) => other.id != c.id && c.conflictsWith(other))
        .toList();
    if (overlaps.isNotEmpty &&
        !await confirm(
          context,
          '课程时间重叠',
          '与 ${overlaps.map((c) => c.name).join('、')} 重叠。是否仍保留这门课程？',
          button: '仍然保存',
        )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = true);
    final ok = await perform(
      context,
      () => ref.read(appControllerProvider.notifier).saveCourse(c),
      success: '课程已保存',
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        goBack(context, '/timetable');
      }
    }
  }
}

class CourseDetailPage extends ConsumerWidget {
  const CourseDetailPage(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);
    final c = data.courses.where((c) => c.id == id).firstOrNull;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('课程详情')),
        body: const EmptyState('课程已不存在', '返回课表查看其他课程。'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('课程详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: courseColor(c.color),
            ),
            const SizedBox(height: 16),
            Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            detailRow('教师', c.teacher),
            detailRow('地点', c.location),
            detailRow(
              '星期',
              '星期${['一', '二', '三', '四', '五', '六', '日'][c.weekday - 1]}',
            ),
            detailRow('节次', '${c.startSection}–${c.endSection} 节'),
            detailRow(
              '教学周',
              '第 ${c.startWeek}–${c.endWeek} 周 · ${c.weekType.label}',
            ),
            detailRow('备注', c.note),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  context.push('/course/edit/${Uri.encodeComponent(id)}'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑课程'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                if (await confirm(
                      context,
                      '删除课程？',
                      '这门课程将从本地课表删除。',
                      button: '删除',
                    ) &&
                    context.mounted) {
                  final ok = await perform(
                    context,
                    () => ref
                        .read(appControllerProvider.notifier)
                        .deleteCourse(id),
                  );
                  if (ok && context.mounted) {
                    goBack(context, '/timetable');
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除课程'),
            ),
          ],
        ),
      ),
    );
  }
}
