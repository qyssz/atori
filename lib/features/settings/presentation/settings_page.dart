import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/app_controller.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../data/exchange_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.person_outline,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '你好，同学',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '游客模式 · 校园日常，安心记录',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          MetricGrid([
            ('本地课程', '${data.courses.length} 门'),
            ('成绩记录', '${data.grades.length} 门'),
          ]),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                _entry(
                  context,
                  Icons.volunteer_activism_outlined,
                  '志愿四川',
                  '每一份善意，都值得被记录',
                  '/volunteer',
                ),
                const Divider(height: 1, indent: 56),
                _entry(
                  context,
                  Icons.folder_outlined,
                  '数据管理',
                  '导入、导出、备份与恢复',
                  '/data',
                ),
                const Divider(height: 1, indent: 56),
                _entry(
                  context,
                  Icons.palette_outlined,
                  '外观与课表设置',
                  '让亚托莉更合你的习惯',
                  '/settings',
                ),
                const Divider(height: 1, indent: 56),
                _entry(
                  context,
                  Icons.info_outline,
                  '关于亚托莉',
                  '版本与隐私说明',
                  '/about',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '数据保存在本机。第二课堂和志愿四川目前使用示例数据。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appControllerProvider).settings;
    Future<void> save(AppSettings Function(AppSettings) transform) =>
        ref.read(appControllerProvider.notifier).updateSettings(transform);
    return Scaffold(
      appBar: AppBar(title: const Text('外观与课表设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('外观', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(settings.theme),
            initialValue: settings.theme,
            decoration: const InputDecoration(labelText: '主题模式'),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('跟随系统')),
              DropdownMenuItem(value: 'light', child: Text('浅色')),
              DropdownMenuItem(value: 'dark', child: Text('深色')),
            ],
            onChanged: (v) {
              if (v != null) {
                perform(context, () => save((s) => s.copyWith(theme: v)));
              }
            },
          ),
          const SizedBox(height: 20),
          const Text('主题色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children:
                [0xFF5867D8, 0xFF277D70, 0xFF9163AC, 0xFFAB683D, 0xFF346E9C]
                    .map(
                      (color) => IconButton(
                        tooltip: '主题色 ${color.toRadixString(16)}',
                        style: IconButton.styleFrom(
                          backgroundColor: Color(color),
                        ),
                        icon: Icon(
                          settings.seedColor == color
                              ? Icons.check
                              : Icons.circle,
                          color: Colors.white,
                        ),
                        onPressed: () => perform(
                          context,
                          () => save((s) => s.copyWith(seedColor: color)),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 28),
          Text('课表显示', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示教师'),
            value: settings.showTeacher,
            onChanged: (v) =>
                perform(context, () => save((s) => s.copyWith(showTeacher: v))),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示教室'),
            value: settings.showLocation,
            onChanged: (v) => perform(
              context,
              () => save((s) => s.copyWith(showLocation: v)),
            ),
          ),
          Text('课程卡片圆角 · ${settings.cardRadius.round()}'),
          Slider(
            value: settings.cardRadius,
            min: 0,
            max: 32,
            divisions: 16,
            onChanged: (v) =>
                perform(context, () => save((s) => s.copyWith(cardRadius: v))),
          ),
          Text('课程卡片透明度 · ${(settings.cardOpacity * 100).round()}%'),
          Slider(
            value: settings.cardOpacity,
            min: 0.3,
            max: 1,
            divisions: 14,
            onChanged: (v) =>
                perform(context, () => save((s) => s.copyWith(cardOpacity: v))),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('上课时间与节次数量'),
            subtitle: Text('当前 ${settings.sectionTimes.length} 节 · 时间可自行调整'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editTimes(context, ref, settings),
          ),
          const SizedBox(height: 16),
          const Text(
            '默认节次时间仅为通用示例。ICS 导出按配置的中国标准时间（UTC+8）生成，请按实际作息调整。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _editTimes(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(
      text: settings.sectionTimes.map((t) => '${t.start}-${t.end}').join('\n'),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('上课时间'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('每行一节，格式 08:00-08:45。保留 1–24 行，按时间顺序排列。'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(labelText: '节次时间'),
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
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) {
      return;
    }
    await perform(context, () async {
      final times = result
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.trim().split('-');
            if (parts.length != 2) {
              throw const FormatException('时间格式须为 HH:mm-HH:mm');
            }
            return SectionTime.fromJson({
              'start': parts[0].trim(),
              'end': parts[1].trim(),
            });
          })
          .toList();
      await ref
          .read(appControllerProvider.notifier)
          .updateSettings(
            (current) => AppSettings.fromJson({
              ...current.toJson(),
              'sectionTimes': times.map((t) => t.toJson()).toList(),
            }),
          );
    }, success: '上课时间已更新');
  }
}

class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});
  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            '当前课表：${data.timetable.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '导入课程会追加到当前课表，生成新 ID；完整备份恢复会替换全部业务数据和设置。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          _section('导入', [
            _tile(Icons.calendar_month, '导入课表 JSON / CSV', _importCourses),
            _tile(Icons.school_outlined, '导入成绩 JSON / CSV', _importGrades),
          ]),
          const SizedBox(height: 20),
          _section('导出', [
            _tile(Icons.code, '课表 JSON', () => _export('courses-json')),
            _tile(Icons.table_view, '课表 CSV', () => _export('courses-csv')),
            _tile(Icons.event_outlined, '课表 ICS 日历', () => _export('ics')),
            _tile(Icons.code, '成绩 JSON', () => _export('grades-json')),
            _tile(Icons.table_view, '成绩 CSV', () => _export('grades-csv')),
          ]),
          const SizedBox(height: 20),
          _section('备份与恢复', [
            _tile(Icons.backup_outlined, '导出完整备份', () => _export('backup')),
            _tile(Icons.restore, '恢复完整备份', _restore),
          ]),
          const SizedBox(height: 20),
          _section('本地数据', [
            _tile(
              Icons.refresh,
              '重新载入活动示例',
              () => _run(
                () =>
                    ref.read(appControllerProvider.notifier).reloadActivities(),
                success: '活动示例已载入',
              ),
            ),
            _tile(Icons.cleaning_services_outlined, '清除活动缓存', () async {
              if (await confirm(
                    context,
                    '清除活动缓存？',
                    '只清除第二课堂与志愿活动记录，保留课表、成绩和设置。',
                  ) &&
                  mounted) {
                await _run(
                  () => ref
                      .read(appControllerProvider.notifier)
                      .clearActivities(),
                  success: '活动缓存已清除',
                );
              }
            }),
            _tile(Icons.delete_outline, '删除全部本地数据', () async {
              if (await confirm(
                    context,
                    '删除全部本地数据？',
                    '课程、成绩、活动及设置将删除。建议先导出备份。',
                    button: '删除',
                  ) &&
                  mounted) {
                await _run(
                  () => ref.read(appControllerProvider.notifier).clearData(),
                  success: '本地数据已清除',
                );
              }
            }),
          ]),
          const SizedBox(height: 20),
          const Text(
            '备份不包含账号、密码、Token 或 Cookie。文件通过系统选择器读写，不申请全盘访问权限。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(child: Column(children: items)),
    ],
  );
  Widget _tile(IconData icon, String label, Future<void> Function() action) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        enabled: !_busy,
        onTap: action,
      );
  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    await perform(context, action, success: success);
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _export(String kind) => _run(() async {
    final saved = await ref.read(exchangeProvider).export(kind);
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('文件已导出')));
    }
  });
  Future<void> _importCourses() => _run(() async {
    final courses = await ref.read(exchangeProvider).pickCourses();
    if (courses == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (courses.isEmpty) {
      throw const FormatException('文件中没有可导入的课程');
    }
    if (await confirm(
      context,
      '导入 ${courses.length} 门课程？',
      '将追加到当前课表，原有课程保留。重叠课程也会保留，可在课表查看和编辑。',
      button: '导入',
    )) {
      await ref
          .read(appControllerProvider.notifier)
          .change(
            (data) => data.copyWith(courses: [...data.courses, ...courses]),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('课程已导入')));
      }
    }
  });
  Future<void> _importGrades() => _run(() async {
    final grades = await ref.read(exchangeProvider).pickGrades();
    if (grades == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (grades.isEmpty) {
      throw const FormatException('文件中没有可导入的成绩');
    }
    if (await confirm(
      context,
      '导入 ${grades.length} 条成绩？',
      '将追加到本地成绩，原有记录保留。',
      button: '导入',
    )) {
      await ref
          .read(appControllerProvider.notifier)
          .change((data) => data.copyWith(grades: [...data.grades, ...grades]));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('成绩已导入')));
      }
    }
  });
  Future<void> _restore() => _run(() async {
    final backup = await ref.read(exchangeProvider).pickBackup();
    if (backup == null || !mounted) {
      return;
    }
    if (await confirm(
      context,
      '恢复备份？',
      '备份包含 ${backup.timetables.length} 份课表、${backup.courses.length} 门课程、${backup.grades.length} 条成绩。恢复会替换当前全部业务数据和设置。',
      button: '恢复',
    )) {
      await ref.read(appControllerProvider.notifier).restore(backup);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('备份已恢复')));
      }
    }
  });
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('关于亚托莉')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 56),
          SizedBox(height: 20),
          Text(
            '亚托莉',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('1.0.0 · 本地校园助手 MVP'),
          SizedBox(height: 28),
          Text('独立实现的校园学习生活助手，提供课表、成绩、活动示例与本地数据管理。'),
          SizedBox(height: 16),
          Text(
            '隐私说明',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Text(
            '当前版本使用游客模式，不需要校园账号，不上传你的课程或成绩。记录保存在本机，可自行导出或删除。活动数据为本地示例，GPA 为示例算法。',
          ),
          SizedBox(height: 16),
          Text('真实校园服务将在完成接口核实后另行接入，并在首次使用前说明处理的数据与用途。'),
          SizedBox(height: 16),
          Text('本应用为独立校园助手，不是四川大学或志愿四川官方应用。'),
        ],
      ),
    ),
  );
}
