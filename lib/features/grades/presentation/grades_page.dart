import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_controller.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../domain/grade_calculator.dart';

class GradesPage extends ConsumerStatefulWidget {
  const GradesPage({super.key});
  @override
  ConsumerState<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends ConsumerState<GradesPage> {
  String _type = '全部', _semester = '全部';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider);
    final semesters = data.grades.map((g) => g.semester).toSet().toList()
      ..sort();
    if (_semester != '全部' && !semesters.contains(_semester)) {
      _semester = '全部';
    }
    final grades = data.grades
        .where(
          (g) =>
              (_type == '全部' || g.courseType == _type) &&
              (_semester == '全部' || g.semester == _semester),
        )
        .toList();
    final calc = GradeCalculator(grades);
    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩'),
        actions: [
          IconButton(
            tooltip: '成绩分析',
            onPressed: () => context.push('/grades/analysis'),
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            tooltip: '导入与导出',
            onPressed: () => context.push('/data'),
            icon: const Icon(Icons.import_export),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_grade'),
        onPressed: () => context.push('/grade/edit/new'),
        icon: const Icon(Icons.add),
        label: const Text('添加成绩'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const PageHeading('每一点进步，都有记录', '查看成绩，也看见自己的成长。'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MetricGrid([
              (
                '加权平均分',
                calc.hasWeightedData
                    ? calc.calculateWeightedAverage().toStringAsFixed(2)
                    : '—',
              ),
              (
                'GPA · 示例 4.0',
                calc.hasGpaData ? calc.calculateGpa().toStringAsFixed(2) : '—',
              ),
              ('已通过学分', calc.calculateTotalCredits().toStringAsFixed(1)),
              (
                '及格率',
                grades.isEmpty
                    ? '—'
                    : '${calc.calculatePassRate().toStringAsFixed(1)}%',
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'GPA 为示例算法，不代表川大官方结果。及格线 60 分。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: '课程属性'),
                    items: ['全部', '必修', '选修', '专业课', '公共课']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (s) => setState(() => _type = s!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_semester),
                    initialValue: _semester,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '学期'),
                    items: ['全部', ...semesters.where((s) => s != '全部')]
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.isEmpty ? '未填写学期' : s,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (s) => setState(() => _semester = s!),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              '课程成绩 · ${grades.length} 门',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (grades.isEmpty)
            const EmptyState(
              '暂无成绩',
              '手动添加或导入成绩，统计会自动更新。',
              icon: Icons.school_outlined,
            ),
          ...grades.map(
            (g) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      onTap: () => context.push(
                        '/grade/edit/${Uri.encodeComponent(g.id)}',
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: const Icon(Icons.menu_book_outlined, size: 20),
                      ),
                      title: Text(
                        g.courseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${g.credit.toStringAsFixed(1)} 学分 · ${g.courseType}\n${g.semester.isEmpty ? '未填写学期' : g.semester}',
                      ),
                      trailing: Text(
                        g.score.toStringAsFixed(g.score % 1 == 0 ? 0 : 1),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: g.score >= 60
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 10, 8),
                      child: Row(
                        children: [
                          Text(
                            '计入 GPA',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Switch(
                            value: g.includedInGpa,
                            onChanged: (v) => perform(
                              context,
                              () => ref
                                  .read(appControllerProvider.notifier)
                                  .saveGrade(
                                    Grade.fromJson({
                                      ...g.toJson(),
                                      'includedInGpa': v,
                                    }),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GradeEditorPage extends ConsumerStatefulWidget {
  const GradeEditorPage(this.id, {super.key});
  final String id;
  @override
  ConsumerState<GradeEditorPage> createState() => _GradeEditorPageState();
}

class _GradeEditorPageState extends ConsumerState<GradeEditorPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  Grade? _grade;
  String _type = '必修';
  bool _included = true, _saving = false;
  @override
  void initState() {
    super.initState();
    final data = ref.read(appControllerProvider);
    _grade = data.grades.where((g) => g.id == widget.id).firstOrNull;
    _type = _grade?.courseType ?? '必修';
    _included = _grade?.includedInGpa ?? true;
    final values = {
      'name': _grade?.courseName ?? '',
      'score': _grade?.score.toString() ?? '',
      'credit': _grade?.credit.toString() ?? '',
      'semester': _grade?.semester ?? '',
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

  Widget _field(String key, String label, {bool number = false}) =>
      TextFormField(
        key: Key('grade_$key'),
        controller: _fields[key],
        decoration: InputDecoration(labelText: label),
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: (v) {
          if (key == 'name' && (v == null || v.trim().isEmpty)) {
            return '请输入课程名称';
          }
          if (number) {
            final n = double.tryParse(v ?? '');
            if (n == null || !n.isFinite || n < 0 || n > 100) {
              return '请输入 0–100 的数值';
            }
          }
          return null;
        },
      );
  @override
  Widget build(BuildContext context) {
    if (widget.id != 'new' && _grade == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('成绩')),
        body: const EmptyState('成绩已不存在', '请返回成绩列表。'),
      );
    }
    final types = {'必修', '选修', '专业课', '公共课', _type};
    return Scaffold(
      appBar: AppBar(title: Text(_grade == null ? '添加成绩' : '编辑成绩')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            children: [
              _field('name', '课程名称'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _field('score', '成绩', number: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('credit', '学分', number: true)),
                ],
              ),
              const SizedBox(height: 16),
              _field('semester', '学期'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '课程属性'),
                items: types
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('计入 GPA'),
                value: _included,
                onChanged: (v) => setState(() => _included = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('grade_save'),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? '正在保存…' : '保存成绩'),
                ),
              ),
              if (_grade != null)
                TextButton.icon(
                  onPressed: () async {
                    if (await confirm(
                          context,
                          '删除成绩？',
                          '这条成绩将从本地数据删除。',
                          button: '删除',
                        ) &&
                        context.mounted) {
                      final ok = await perform(
                        context,
                        () => ref
                            .read(appControllerProvider.notifier)
                            .deleteGrade(_grade!.id),
                      );
                      if (ok && context.mounted) {
                        goBack(context, '/grades');
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除成绩'),
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
    setState(() => _saving = true);
    final grade = Grade(
      id: _grade?.id ?? const Uuid().v4(),
      courseName: _fields['name']!.text.trim(),
      score: double.parse(_fields['score']!.text),
      credit: double.parse(_fields['credit']!.text),
      semester: _fields['semester']!.text.trim(),
      courseType: _type,
      includedInGpa: _included,
    );
    final ok = await perform(
      context,
      () => ref.read(appControllerProvider.notifier).saveGrade(grade),
      success: '成绩已保存',
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        goBack(context, '/grades');
      }
    }
  }
}

class GradeAnalysisPage extends ConsumerWidget {
  const GradeAnalysisPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(appControllerProvider).grades;
    final calc = GradeCalculator(grades);
    final semesters = grades.map((g) => g.semester).toSet().toList()..sort();
    final bins = calc.distribution();
    return Scaffold(
      appBar: AppBar(title: const Text('成绩分析')),
      body: grades.isEmpty
          ? const EmptyState('暂无分析数据', '先添加一些成绩，再来看看自己的学习轨迹。')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '全部成绩的学期趋势',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ...semesters.map((semester) {
                  final c = GradeCalculator(
                    grades.where((g) => g.semester == semester),
                  );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            semester.isEmpty ? '未填写学期' : semester,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '加权平均 ${c.hasWeightedData ? c.calculateWeightedAverage().toStringAsFixed(2) : '—'}   ·   GPA ${c.hasGpaData ? c.calculateGpa().toStringAsFixed(2) : '—'}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '已通过 ${c.calculateTotalCredits().toStringAsFixed(1)} 学分 · 及格率 ${c.calculatePassRate().toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                Text('成绩分布', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: Text(
                            ['90–100', '80–<90', '70–<80', '60–<70', '<60'][i],
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: bins[i] / grades.length,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${bins[i]} 门'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'GPA 使用示例 4.0 策略：<60 为 0；60–90 线性映射到 1–4；≥90 为 4。不代表川大官方算法。',
                ),
              ],
            ),
    );
  }
}
