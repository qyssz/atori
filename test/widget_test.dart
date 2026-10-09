import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:atori/app/app.dart';
import 'package:atori/core/storage/app_controller.dart';
import 'package:atori/core/storage/app_repository.dart';
import 'package:atori/shared/models/models.dart';

class WidgetSource implements LocalDataSource {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  AppData data, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(AppRepository(WidgetSource(), data)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AtoriApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> tab(WidgetTester tester, String name) async {
  await tester.tap(
    find
        .descendant(of: find.byType(NavigationBar), matching: find.text(name))
        .last,
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));
  testWidgets('大量重叠课程仍可打开，特殊ID不会破坏路由', (tester) async {
    final courses = List.generate(
      20,
      (i) => Course(
        id: i == 0 ? 'id/包含 空格?#' : 'overlap-$i',
        timetableId: 'main',
        name: '重叠课程$i',
        weekday: 1,
        startSection: 1,
        endSection: 1,
        startWeek: 1,
        endWeek: 20,
      ),
    );
    await pumpApp(
      tester,
      AppData.empty().copyWith(courses: courses),
      size: const Size(320, 740),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('重叠课程0'));
    await tester.pumpAndSettle();
    expect(find.text('课程详情'), findsOneWidget);
    expect(find.text('重叠课程0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('四栏、活动详情、志愿入口与窄屏布局', (tester) async {
    final data = (await tester.runAsync(() => MockDataSource().initialData()))!;
    final container = await pumpApp(tester, data, size: const Size(320, 740));
    expect(find.byKey(const Key('add_course')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tab(tester, '成绩');
    expect(find.text('加权平均分'), findsOneWidget);
    await tab(tester, '第二课堂');
    final activity = find.text(data.secondClass.first.title);
    await tester.ensureVisible(activity);
    await tester.tap(activity);
    await tester.pumpAndSettle();
    expect(find.text('活动详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('志愿四川'));
    await tester.pumpAndSettle();
    expect(find.text('已完成志愿时长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('手动添加、编辑、删除课程', (tester) async {
    final container = await pumpApp(tester, AppData.empty());
    await tester.tap(find.byKey(const Key('add_course')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course_name')), '测试数学');
    await tester.enterText(find.byKey(const Key('course_teacher')), '测试教师');
    final save = find.byKey(const Key('course_save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(container.read(appControllerProvider).courses.single.name, '测试数学');
    // Let the success snackbar finish before immediately opening another form.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final id = container.read(appControllerProvider).courses.single.id;
    container.read(routerProvider).push('/course/edit/$id');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course_name')), '已修改数学');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(container.read(appControllerProvider).courses.single.name, '已修改数学');
    container.read(routerProvider).go('/course/detail/$id');
    await tester.pumpAndSettle();
    final delete = find.text('删除课程');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(container.read(appControllerProvider).courses, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('成绩计算、GPA开关与深色设置', (tester) async {
    final data = AppData.empty().copyWith(
      grades: [
        const Grade(id: 'A', courseName: '数学', score: 95, credit: 4),
        const Grade(id: 'B', courseName: '英语', score: 80, credit: 2),
      ],
    );
    final container = await pumpApp(tester, data);
    await tab(tester, '成绩');
    expect(find.text('90.00'), findsOneWidget);
    final toggle = find.byType(Switch).first;
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      container
          .read(appControllerProvider)
          .grades
          .firstWhere((g) => g.id == 'A')
          .includedInGpa,
      isFalse,
    );
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    expect(container.read(appControllerProvider).settings.theme, 'dark');
    expect(tester.takeException(), isNull);
  });
  testWidgets('所有主要路由在浅色与深色模式无布局异常', (tester) async {
    final data = (await tester.runAsync(() => MockDataSource().initialData()))!;
    final container = await pumpApp(tester, data);
    for (final dark in [false, true]) {
      await tester.runAsync(
        () => container
            .read(appControllerProvider.notifier)
            .settings(data.settings.copyWith(theme: dark ? 'dark' : 'light')),
      );
      for (final route in [
        '/timetable',
        '/grades',
        '/grades/analysis',
        '/second-class',
        '/profile',
        '/volunteer',
        '/settings',
        '/data',
        '/about',
      ]) {
        container.read(routerProvider).go(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.takeException(),
          isNull,
          reason: 'route=$route, dark=$dark',
        );
      }
    }
  });
}
