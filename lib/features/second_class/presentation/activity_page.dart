import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/app_controller.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';

String statusLabel(String status) => switch (status) {
  'available' => '可报名',
  'registered' => '已报名',
  'ongoing' => '进行中',
  'completed' => '已完成',
  'ended' => '已结束',
  _ => '未知',
};

class ActivityView {
  const ActivityView(
    this.id,
    this.title,
    this.category,
    this.location,
    this.description,
    this.start,
    this.end,
    this.status,
    this.value,
    this.organizer, [
    this.registrationStart,
    this.registrationEnd,
  ]);
  final String id, title, category, location, description, status, organizer;
  final DateTime start, end;
  final DateTime? registrationStart, registrationEnd;
  final double value;
  factory ActivityView.second(SecondClassActivity a) => ActivityView(
    a.id,
    a.title,
    a.category,
    a.location,
    a.description,
    a.startTime,
    a.endTime,
    a.status.name,
    a.score,
    a.organizer,
    a.registrationStart,
    a.registrationEnd,
  );
  factory ActivityView.volunteer(VolunteerActivity a) => ActivityView(
    a.id,
    a.title,
    '志愿服务',
    a.location,
    a.description,
    a.startTime,
    a.endTime,
    a.status.name,
    a.hours,
    '',
  );
}

class ActivityListPage extends ConsumerStatefulWidget {
  const ActivityListPage({super.key, this.volunteer = false});
  final bool volunteer;
  @override
  ConsumerState<ActivityListPage> createState() => _ActivityListPageState();
}

class _ActivityListPageState extends ConsumerState<ActivityListPage> {
  String _filter = 'all';
  bool _loading = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider);
    final all = widget.volunteer
        ? data.volunteer.map(ActivityView.volunteer).toList()
        : data.secondClass.map(ActivityView.second).toList();
    final entries = all
        .where((a) => _filter == 'all' || a.status == _filter)
        .toList();
    final completed = all.where((a) => a.status == 'completed').toList();
    final value = completed.fold<double>(0, (s, a) => s + a.value);
    final base = widget.volunteer ? '/volunteer' : '/second-class';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.volunteer ? '志愿四川' : '第二课堂'),
        actions: [
          IconButton(
            tooltip: '刷新活动示例',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? EmptyState(
              '活动暂时无法加载',
              _error!,
              action: FilledButton(onPressed: _reload, child: const Text('重试')),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                PageHeading(
                  widget.volunteer ? '让善意，留下足迹' : '课堂之外，也有精彩',
                  widget.volunteer ? '记录每一次参与与付出。' : '探索兴趣，遇见更广阔的校园。',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MetricGrid([
                    (
                      widget.volunteer ? '已完成志愿时长' : '已获第二课堂分',
                      '${value.toStringAsFixed(1)}${widget.volunteer ? ' h' : ''}',
                    ),
                    ('已完成活动', '${completed.length}'),
                    (
                      '当前已报名',
                      '${all.where((a) => a.status == 'registered' || a.status == 'ongoing').length}',
                    ),
                    ('全部活动', '${all.length}'),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    '本地示例数据 · 未连接真实服务，不提供真实报名。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      ...[
                        'all',
                        'available',
                        'registered',
                        if (widget.volunteer) 'ongoing',
                        'completed',
                        'ended',
                      ].map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              status == 'all' ? '全部' : statusLabel(status),
                            ),
                            selected: _filter == status,
                            onSelected: (_) => setState(() => _filter = status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  EmptyState(
                    '暂无活动',
                    '切换状态筛选，或重新载入活动示例。',
                    action: TextButton(
                      onPressed: _reload,
                      child: const Text('载入活动示例'),
                    ),
                  ),
                ...entries.map(
                  (a) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(
                          '$base/detail/${Uri.encodeComponent(a.id)}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.category,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    statusLabel(a.status),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                a.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${DateFormat('M 月 d 日 HH:mm').format(a.start.toLocal())} · ${a.location}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.volunteer
                                    ? '${a.value.toStringAsFixed(1)} 小时'
                                    : '${a.value.toStringAsFixed(1)} 分',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final ok = await perform(
      context,
      () => ref.read(appControllerProvider.notifier).reloadActivities(),
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _error = ok ? null : '示例数据加载失败，请重试。';
      });
    }
  }
}

class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage(this.id, {super.key, this.volunteer = false});
  final String id;
  final bool volunteer;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);
    final items = volunteer
        ? data.volunteer.map(ActivityView.volunteer)
        : data.secondClass.map(ActivityView.second);
    final a = items.where((a) => a.id == id).firstOrNull;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('活动详情')),
        body: const EmptyState('活动已不存在', '请返回列表重新载入示例活动。'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('活动详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              volunteer
                  ? Icons.volunteer_activism_outlined
                  : Icons.local_activity_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Chip(label: Text('${statusLabel(a.status)} · 示例')),
            const SizedBox(height: 16),
            detailRow('类型', a.category),
            if (a.organizer.isNotEmpty) detailRow('主办单位', a.organizer),
            detailRow(
              '开始时间',
              DateFormat('yyyy-MM-dd HH:mm').format(a.start.toLocal()),
            ),
            detailRow(
              '结束时间',
              DateFormat('yyyy-MM-dd HH:mm').format(a.end.toLocal()),
            ),
            detailRow('地点', a.location),
            if (!volunteer)
              detailRow(
                '报名时间',
                a.registrationStart == null
                    ? '未提供'
                    : '${DateFormat('yyyy-MM-dd HH:mm').format(a.registrationStart!.toLocal())} 至 ${DateFormat('yyyy-MM-dd HH:mm').format(a.registrationEnd!.toLocal())}',
              ),
            detailRow(
              volunteer ? '志愿时长' : '活动分数',
              '${a.value.toStringAsFixed(1)} ${volunteer ? '小时' : '分'}',
            ),
            const SizedBox(height: 16),
            Text('活动说明', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(a.description),
            const SizedBox(height: 24),
            const Text('这是一条本地示例记录。报名与真实数据同步将在后续版本接入。'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  goBack(context, volunteer ? '/volunteer' : '/second-class'),
              child: const Text('返回活动列表'),
            ),
          ],
        ),
      ),
    );
  }
}
