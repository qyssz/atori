# 亚托莉校园助手 App 开发需求文档

> 文档类型：产品需求 + 技术实现规范 + AI 编程提示词\
> 目标平台：Android\
> 技术建议：Flutter + Dart\
> 参考项目：<https://github.com/The-Brotherhood-of-SCU/Bugaoshan>\
> 当前版本目标：先完成可安装、可运行、UI 完整的 MVP，再逐步接入真实校园服务。

---

## 1. 项目目标

开发一款面向四川大学学生的校园学习生活助手 App。

整体产品思路参考 **不高山上 / Bugaoshan**，但不直接复制其源代码、图标、文案、图片或专有资源。

第一阶段仅保留以下四个核心模块：

1. 课表
2. 成绩统计与计算
3. 第二课堂
4. 志愿四川

其他功能暂时不实现，后续再以独立模块加入。

应用暂定名称：

**亚托莉**

优先目标是生成 **Android APK**。

---

## 2. 开发原则

### 2.1 Clean-room 实现

参考 Bugaoshan 的产品思路、信息架构和交互逻辑，但：

- 不直接复制原项目 Dart 源代码；
- 不复制原项目 UI 素材；
- 不复制原项目图标；
- 不冒充官方四川大学 App；
- 不在没有授权的情况下使用四川大学官方标识；
- 网络接口必须由开发者确认合法、稳定后再接入；
- 如果后续直接复用 AGPL-3.0 项目的代码，必须遵守其开源许可证要求。

### 2.2 MVP 优先

第一阶段重点：

- 能启动；
- 能正常切换页面；
- 页面 UI 完整；
- 本地数据可用；
- 课表可以录入/导入；
- 成绩可以计算；
- 第二课堂和志愿四川先完成数据展示框架；
- 可以成功打包 APK。

不要一开始实现过多校园功能。

---

# 3. 技术栈

## 3.1 客户端

使用：

```text
Flutter
Dart
Material 3
```

推荐最低版本：

```text
Flutter 3.x+
Dart 3.x+
Android SDK 35+
minSdkVersion 23
```

---

## 3.2 状态管理

推荐：

```text
Riverpod
```

如果项目规模较小时也可以使用：

```text
Provider
```

优先 Riverpod。

---

## 3.3 本地存储

推荐：

```text
Hive / Isar
SharedPreferences
Flutter Secure Storage
```

用途：

| 数据 | 存储方式 |
|---|---|
| 用户设置 | SharedPreferences |
| 课表 | Isar / Hive |
| 成绩 | Isar / Hive |
| 登录 Token | Flutter Secure Storage |
| 第二课堂缓存 | Isar / Hive |
| 志愿四川缓存 | Isar / Hive |

密码、Token、Cookie 等敏感数据禁止直接明文写入普通数据库。

---

## 3.4 网络请求

推荐：

```text
Dio
```

统一封装：

```text
ApiClient
AuthInterceptor
ErrorInterceptor
CookieManager
```

任何网络请求都不能直接写在 UI 页面中。

---

# 4. 项目目录结构

建议结构：

```text
lib/
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
│
├── core/
│   ├── constants/
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── auth_interceptor.dart
│   │   └── api_exception.dart
│   │
│   ├── storage/
│   ├── utils/
│   └── widgets/
│
├── features/
│   │
│   ├── timetable/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── grades/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── second_class/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── volunteer/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── settings/
│       ├── data/
│       └── presentation/
│
└── shared/
    ├── models/
    └── widgets/
```

原则：

```text
UI
↓
Provider / Controller
↓
Repository
↓
Local / Remote DataSource
```

UI 不允许直接调用 HTTP。

---

# 5. 整体导航

App 使用底部导航栏。

底部四个入口：

```text
课表
成绩
第二课堂
我的
```

其中：

```text
“我的”页面内放：
- 志愿四川
- 数据管理
- 外观设置
- 关于
```

也可以后续改成五栏：

```text
课表 / 成绩 / 第二课堂 / 志愿 / 我的
```

第一版推荐四栏，界面更简洁。

---

# 6. 首页 / 课表

## 6.1 页面目标

打开 App 后默认进入课表页面。

顶部显示：

```text
2026-2027 秋
第 6 周
10 月 9 日
```

主体显示周课表。

示例：

```text
        周一 周二 周三 周四 周五
1-2节
3-4节
5-6节
7-8节
9-10节
```

课程使用彩色卡片显示。

---

## 6.2 课程卡片

卡片显示：

```text
课程名称
教室
教师
节次
```

示例：

```text
高等数学
综合楼 B305
张老师
1-2 节
```

点击课程弹出详情：

```text
课程名称
教师
地点
星期
开始节次
结束节次
起始周
结束周
单双周
备注
```

---

## 6.3 课程数据模型

```dart
class Course {
  String id;
  String name;
  String teacher;
  String location;

  int weekday;

  int startSection;
  int endSection;

  int startWeek;
  int endWeek;

  WeekType weekType;

  String? color;
  String? note;
}
```

其中：

```dart
enum WeekType {
  all,
  odd,
  even,
}
```

---

# 7. 课表功能

第一阶段实现：

- 查看周课表
- 左右切换周
- 返回当前周
- 添加课程
- 编辑课程
- 删除课程
- 多课表
- 导入课表
- 导出课表
- ICS 导出
- 本地备份

---

## 7.1 手动添加课程

页面字段：

```text
课程名称 *
教师
教室
星期 *
开始节次 *
结束节次 *
开始周 *
结束周 *
单双周
备注
```

必须校验：

```text
startSection <= endSection
startWeek <= endWeek
weekday = 1...7
```

---

# 8. 课表导入

设计统一接口：

```dart
abstract class TimetableImporter {
  Future<List<Course>> import();
}
```

实现：

```text
ManualImporter
JsonImporter
CsvImporter
IcsImporter
SchoolImporter
```

第一版先实现：

```text
手动添加
JSON
CSV
```

学校教务系统导入作为后续功能。

---

# 9. 成绩模块

## 9.1 成绩页面

顶部显示：

```text
平均分
GPA
已修学分
及格率
```

例如：

```text
平均分 86.42

GPA
3.71

已修学分
38.5

及格率
97.3%
```

---

## 9.2 成绩列表

每项：

```text
课程名称
成绩
学分
课程属性
学期
```

示例：

```text
高等数学 A
92
5.0 学分
必修
2026-2027-1
```

---

## 9.3 成绩数据模型

```dart
class Grade {
  String id;

  String courseName;

  double score;
  double credit;

  String semester;

  String courseType;

  bool includedInGpa;
}
```

---

# 10. 成绩计算

必须提供独立工具类：

```text
GradeCalculator
```

包含：

```dart
double calculateAverage();
double calculateWeightedAverage();
double calculateGpa();
double calculatePassRate();
double calculateTotalCredits();
```

---

## 10.1 加权平均分

公式：

```text
Σ(成绩 × 学分)
──────────────
   Σ学分
```

代码逻辑：

```dart
weightedAverage =
    sum(score * credit) /
    sum(credit);
```

---

## 10.2 GPA

不要把 GPA 算法写死。

设计：

```dart
abstract class GpaStrategy {
  double scoreToGpa(double score);
}
```

允许以后添加：

```text
SCU GPA
4.0 制
4.3 制
用户自定义
```

---

# 11. 成绩筛选

支持：

```text
全部
必修
选修
专业课
公共课
按学期
```

支持用户选择：

```text
是否计入 GPA
```

---

# 12. 成绩分析

增加简单分析页面。

展示：

```text
各学期平均分
各学期 GPA
成绩分布
已修学分
课程通过率
```

成绩区间：

```text
90-100
80-89
70-79
60-69
<60
```

图表可以使用：

```text
fl_chart
```

---

# 13. 第二课堂模块

页面顶部：

```text
第二课堂
```

卡片显示：

```text
当前分数
已完成活动
待参加活动
```

例如：

```text
第二课堂分
8.5

已完成
12

待参加
2
```

---

# 14. 第二课堂活动

活动列表显示：

```text
活动名称
类型
时间
地点
状态
```

状态：

```text
可报名
已报名
已完成
已结束
```

活动详情：

```text
活动名称
主办单位
时间
地点
活动说明
报名时间
获得分数
```

---

# 15. 第二课堂数据模型

```dart
class SecondClassActivity {
  String id;

  String title;

  String category;

  DateTime startTime;
  DateTime endTime;

  String location;

  double? score;

  ActivityStatus status;

  String? description;
}
```

---

# 16. 志愿四川模块

入口：

```text
我的
→ 志愿四川
```

页面包含：

```text
志愿时长
志愿活动次数
当前报名活动
历史活动
```

---

# 17. 志愿活动列表

卡片：

```text
活动名称
活动时间
活动地点
志愿时长
状态
```

状态：

```text
可报名
已报名
进行中
已完成
已结束
```

---

# 18. 志愿活动数据模型

```dart
class VolunteerActivity {
  String id;

  String title;

  DateTime startTime;
  DateTime endTime;

  String location;

  double hours;

  VolunteerStatus status;

  String? description;
}
```

---

# 19. “我的”页面

显示：

```text
头像

昵称
学号（允许隐藏）

----------------

志愿四川

数据管理

外观设置

关于亚托莉
```

不要默认公开展示用户敏感信息。

---

# 20. 设置页面

## 20.1 外观

支持：

```text
浅色
深色
跟随系统
```

支持：

```text
主题色
```

推荐 Material 3 动态颜色。

---

## 20.2 课表设置

支持：

```text
上课时间
节次数量
课程卡片圆角
课程卡片透明度
是否显示教师
是否显示教室
```

---

# 21. UI 设计要求

整体风格：

```text
Material 3
简洁
圆角
轻量
校园风
现代 Android
```

避免完全照搬 Bugaoshan。

建议：

```text
Card Radius: 16
Button Radius: 14
Page Padding: 16
```

页面应同时支持：

```text
Light Mode
Dark Mode
```

---

# 22. 动效

页面切换：

```text
200-300ms
```

课表卡片：

```text
轻微缩放
淡入
```

禁止：

```text
过度动画
长时间加载动画
影响操作的转场
```

---

# 23. 加载状态

所有网络页面必须提供：

```text
Loading
Success
Empty
Error
```

例如：

```dart
sealed class ViewState<T> {}

class Loading<T> extends ViewState<T> {}

class Success<T> extends ViewState<T> {
  final T data;
}

class Empty<T> extends ViewState<T> {}

class Error<T> extends ViewState<T> {
  final String message;
}
```

---

# 24. 错误提示

禁止直接向用户显示：

```text
DioException
SocketException
NullPointerException
```

应转换为：

```text
网络连接失败，请检查网络

登录状态已过期，请重新登录

服务器暂时不可用

数据解析失败
```

---

# 25. 网络接口设计

所有真实校园接口都通过：

```text
Repository
```

访问。

例如：

```dart
class TimetableRepository {
  Future<List<Course>> getCourses();
}

class GradeRepository {
  Future<List<Grade>> getGrades();
}

class SecondClassRepository {
  Future<List<SecondClassActivity>> getActivities();
}

class VolunteerRepository {
  Future<List<VolunteerActivity>> getActivities();
}
```

---

# 26. Mock 数据

在没有真实接口时必须保证 App 可运行。

创建：

```text
assets/mock/
```

包含：

```text
courses.json
grades.json
second_class.json
volunteer.json
```

Debug 模式允许：

```text
USE_MOCK_DATA = true
```

这样 UI 开发不依赖真实校园服务器。

---

# 27. 登录设计

第一版不要强依赖登录。

启动后：

```text
游客模式
```

可以直接查看：

```text
本地课表
本地成绩
Mock 第二课堂
Mock 志愿活动
```

后续接入真实校园服务时再加入：

```text
四川大学账号登录
```

---

# 28. 安全要求

必须遵守：

```text
密码禁止打印到日志
Token 禁止明文存储
Cookie 禁止写入普通文本文件
Release 禁止输出敏感网络日志
HTTPS 证书错误不能直接忽略
```

禁止：

```dart
badCertificateCallback = (...) => true;
```

Release 版本必须关闭调试日志。

---

# 29. 隐私

首次使用真实校园服务前显示隐私说明。

明确说明可能处理：

```text
课表
成绩
校园账号身份信息
第二课堂信息
志愿活动信息
```

只保存实现功能所需要的数据。

提供：

```text
清除缓存
清除登录信息
删除本地数据
```

---

# 30. 数据导出

支持：

```text
课表 JSON
课表 ICS
成绩 JSON
成绩 CSV
完整数据备份 JSON
```

---

# 31. 数据备份

备份文件结构示例：

```json
{
  "version": 1,
  "createdAt": "2026-10-09T12:00:00Z",
  "courses": [],
  "grades": [],
  "settings": {}
}
```

导入前必须验证：

```text
version
数据格式
字段类型
```

---

# 32. 路由设计

建议：

```text
/
│
├── /timetable
├── /course/detail/:id
├── /course/edit/:id
│
├── /grades
├── /grades/analysis
│
├── /second-class
├── /second-class/detail/:id
│
├── /profile
├── /volunteer
├── /volunteer/detail/:id
│
└── /settings
```

推荐：

```text
go_router
```

---

# 33. 推荐依赖

```yaml
dependencies:
  flutter:
    sdk: flutter

  flutter_riverpod:
  go_router:
  dio:
  flutter_secure_storage:
  shared_preferences:
  intl:
  uuid:
  fl_chart:
```

数据库二选一：

```yaml
isar:
```

或：

```yaml
hive:
```

不要同时加入大量重复功能的第三方库。

---

# 34. 首页状态恢复

App 再次打开时：

```text
恢复上一次打开的底部页面
恢复课表当前学期
默认回到当前周
```

---

# 35. 空状态

示例：

### 没有课程

```text
今天没有课程

好好休息一下吧
```

### 没有成绩

```text
暂无成绩

你可以手动添加或导入成绩
```

### 没有第二课堂活动

```text
暂无活动
```

---

# 36. Android 权限

第一版尽量减少权限。

可能使用：

```text
INTERNET
```

如果导入/导出使用系统文件选择器，则优先使用 Android Storage Access Framework。

不要为了保存文件申请不必要的全盘文件权限。

---

# 37. Android 构建

最终必须可以运行：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

输出：

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# 38. 第一阶段验收标准

必须全部满足：

- [ ] Android 可以安装
- [ ] App 可以正常启动
- [ ] 无启动崩溃
- [ ] 底部导航正常
- [ ] 可以查看周课表
- [ ] 可以手动增加课程
- [ ] 可以修改课程
- [ ] 可以删除课程
- [ ] 关闭 App 后课程仍存在
- [ ] 可以查看成绩
- [ ] 可以计算加权平均分
- [ ] 可以计算 GPA
- [ ] 可以统计学分
- [ ] 可以筛选成绩
- [ ] 第二课堂页面完整
- [ ] 志愿四川页面完整
- [ ] 深色模式可正常显示
- [ ] 没有明显 UI 溢出
- [ ] `flutter analyze` 没有严重错误
- [ ] Release APK 构建成功

---

# 39. 第二阶段

完成 MVP 后再开发：

```text
教务系统课表导入
真实成绩同步
真实第二课堂数据
真实志愿四川数据
考试安排
桌面课表组件
通知提醒
```

---

# 40. 第三阶段

再考虑：

```text
校园卡
校园网
空闲教室
校历
培养方案
通知公告
电费
微服务
```

这些功能第一版禁止提前加入。

---

# 41. 测试要求

至少为以下逻辑编写单元测试：

```text
单双周课程判断
课程是否处于当前周
课程时间冲突
加权平均分
GPA
学分统计
及格率
备份导入
```

示例：

```text
95 分 × 4 学分
80 分 × 2 学分

加权平均分：

(95×4 + 80×2) / 6
= 90
```

---

# 42. Git 提交规范

推荐：

```text
feat:
fix:
refactor:
docs:
test:
chore:
```

例如：

```text
feat: add timetable page
feat: add grade calculator
fix: resolve course card overflow
```

---

# 43. AI 编程执行规则

如果本文件交给 Codex、Claude Code、Cursor 或其他 Coding Agent：

## 必须遵守

1. 先扫描现有项目。
2. 不随意删除已经工作的代码。
3. 每完成一个模块运行：

```bash
dart format .
flutter analyze
flutter test
```

4. 发现错误立即修复。
5. 不允许只创建空页面。
6. 不允许使用 TODO 假装完成核心功能。
7. 所有页面必须可进入。
8. 所有按钮必须有实际响应。
9. 不要一次性重构整个项目。
10. 每次修改保持可编译状态。

---

# 44. AI 开发顺序

严格按照以下顺序开发。

## Step 1

创建 Flutter 项目骨架。

完成：

```text
主题
路由
底部导航
文件结构
```

---

## Step 2

完成本地数据库。

创建：

```text
Course
Grade
SecondClassActivity
VolunteerActivity
```

---

## Step 3

完成课表模块。

顺序：

```text
周课表 UI
↓
添加课程
↓
编辑课程
↓
删除课程
↓
持久化
↓
课程详情
```

---

## Step 4

完成成绩模块。

顺序：

```text
成绩列表
↓
GradeCalculator
↓
统计卡片
↓
GPA
↓
筛选
↓
成绩分析
```

---

## Step 5

完成第二课堂。

先使用：

```text
Mock JSON
```

实现：

```text
活动列表
活动详情
状态筛选
```

---

## Step 6

完成志愿四川。

先使用：

```text
Mock JSON
```

实现：

```text
志愿时长
活动列表
活动详情
历史记录
```

---

## Step 7

完成设置。

实现：

```text
深色模式
主题色
课表显示设置
数据清除
```

---

## Step 8

打包 APK。

执行：

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

---

# 45. Coding Agent 主提示词

将以下内容作为 Coding Agent 的总任务：

```text
你是一名资深 Flutter Android 工程师。

请根据仓库根目录中的本需求文档开发“亚托莉”校园助手 App。

参考 Bugaoshan 的校园助手产品思路，但必须进行独立实现，不复制其代码、素材或品牌。

第一版只实现：

1. 课表
2. 成绩统计与计算
3. 第二课堂
4. 志愿四川
5. 基础设置

目标是生成一个可以在 Android 真机安装运行的 Release APK。

技术栈：

Flutter
Dart
Material 3
Riverpod
go_router
Dio
本地数据库
flutter_secure_storage

架构必须保持：

UI
→ Controller / Provider
→ Repository
→ DataSource

先使用本地 Mock 数据开发 UI 和业务逻辑，不要因为缺少真实校园接口而阻塞项目。

每完成一个阶段必须执行：

dart format .
flutter analyze
flutter test

修复错误后再继续。

禁止提交无法编译的代码。

禁止将核心功能留成 TODO。

不要提前加入校园卡、校园网、空闲教室等不属于第一阶段的模块。

最终必须成功执行：

flutter build apk --release

并确保生成：

build/app/outputs/flutter-apk/app-release.apk
```

---

# 46. 最终交付物

项目最终至少应包含：

```text
README.md
PROJECT_SPEC.md
pubspec.yaml
lib/
assets/
test/
android/
```

Release：

```text
app-release.apk
```

README 中必须包含：

```text
项目介绍
功能列表
环境要求
运行方法
构建 APK 方法
项目结构
隐私说明
```

---

# 47. 当前版本产品范围总结

**第一版只做：**

```text
课表
成绩
第二课堂
志愿四川
设置
```

**暂时不做：**

```text
校园卡
校园网
宿舍电费
空闲教室
报修
请假
培养方案
考试查询
校历
通知公告
桌面小组件
```

原则：

> 先把 4 个核心模块做稳定，再继续扩展。
