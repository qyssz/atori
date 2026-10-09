# 项目现状报告

更新日期：2026-10-09。工作目录：`D:/项目/app`。

## 范围变化与依据

初始扫描只有 `PROJECT_SPEC.md`，没有应用、Git 仓库、Flutter 或 Android 工具链。先前已完成现状梳理和开发清单。用户随后要求“开始”“按md文件制作”，本轮按该需求文件实现 Android MVP。原始规格保留。

## 当前结构与功能

| 模块 | 状态 | 实现位置与证据 |
|---|---|---|
| 工程、主题、路由 | 已实现 | lib/main.dart、lib/app/app.dart；四栏及全部主要路由浅/深色界面测试 |
| 本地存储 | 已实现 | core/storage；单快照 Hive、串行写入、失败不发布；真实文件关闭重开测试 |
| 课表 | 已实现 | features/timetable；多课表、周/单双周、增删改、冲突提示、详情、学期设置 |
| 成绩 | 已实现 | features/grades；独立 GradeCalculator、GpaStrategy、筛选、分析、持久化 |
| 第二课堂 | 本地展示已实现 | Mock 列表、详情含报名时间、筛选、完成分数及状态反馈 |
| 志愿四川 | 本地展示已实现 | 我的入口、列表、详情、状态筛选、已完成时长/次数 |
| 设置与恢复 | 已实现 | 主题色、三种模式、显示偏好、节次、当前课表及底部页面恢复 |
| 数据交换 | 已实现 | 文件选择器、课程/成绩 JSON/CSV、ICS、完整备份与原子恢复 |
| 官方 GPA、真实登录/同步 | 待后续开发 | 没有已确认接口或官方计算规则，页面明确使用示例 |
| APK 安装验收 | 见交付记录 | 构建、设备与截图结果逐项记录，不以单元测试代替设备验证 |

当前已经通过 `flutter analyze`（No issues found）和 **27 项 Flutter 测试**。构建与 Android 运行结果见 [交付记录](DELIVERY_REPORT.md)。

## 运行条件

| 项目 | 当前配置 |
|---|---|
| Flutter / Dart | 3.47.7 / 3.13.5；D:/atori-sdk/flutter |
| Android SDK | D:/atori-sdk/android；compile/target 36、build-tools 36.0.0、NDK 28.2.13676358 |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0，沿用当前 Flutter 模板 |
| Java | D:/编程/jdk，Temurin 25.0.4.1 |
| 最低 Android | API 24；当前 stable 的最低要求，较规格建议的 23 提高一级 |
| Pub / 临时缓存 | D:/atori-sdk/pub-cache、temp；避免跨磁盘重命名失败 |
| 构建工作副本 | D:/atori-sdk/atori-workspace；规避中文路径分析协议错误 |
| 登录与远程配置 | 无需配置；离线游客 MVP |
| Git | 已上传至公开仓库 [qyssz/atori](https://github.com/qyssz/atori)，main 分支；忽略个人导入、缓存、备份及签名文件；v1.0.0 Release 已发布 APK 和校验文件 |
| Android 设备 | API 36 x86_64 测试模拟器 emulator-5556；未连接实体手机 |

源码、SDK 与缓存分别存放；辅助脚本不持久修改 PATH。SDK 与 Gradle 压缩包在使用前验证校验值。

## 已定位的环境问题

| 问题 | 触发与影响 | 处理 |
|---|---|---|
| 沙箱命令启动失败 | setup refresh had errors；工具层命令未启动 | 经自动审批在沙箱外执行限于本任务的命令；不是 App 缺陷 |
| Pub 跨卷缓存重命名 | C: 默认缓存与 D: 临时路径，初始化失败 | 当前进程 PUB_CACHE、TEMP、TMP 均置于 D:/atori-sdk |
| 中文路径分析服务失败 | 本目录运行 analyze 时消息长度错误 | 在英文路径复制构建，原源码位置不变 |
| Gradle 下载重定向不可达 | 官方发行地址跳转 GitHub，下载阻塞 | 本地使用官方 SHA256 验证的镜像压缩包；源码保留官方 URL |
| 新 Android CLI 兼容问题 | sdkmanager 旧分号参数不能正确安装 NDK | 安装脚本调用新版 android.exe 的斜杠组件标识，并检查实际文件 |
| minSdk 23 被迁移 | 当前 Flutter 最低 API 24 | 使用 flutter.minSdkVersion，明确记录 Android 7.0 要求 |

首次 NDK 缺失的构建错误被 Flutter 附带显示为 Java 兼容提示；实际阻塞是组件未安装，按具体 Gradle 错误解决。

## 数据与兼容约定

Course 额外保存 timetableId；完整备份 version=1 包含多课表及所选 ID，防止仅保存课程导致归属丢失。普通导入生成新 ID；完整恢复保留原 ID。可选报名时间字段兼容没有该字段的早期备份。坏版本、类型、日期、范围、重复 ID、悬空课表、逆序节次均拒绝。

用户设置与业务数据共同保存于 Hive 单快照，与规格建议的“设置用 SharedPreferences”不同；这样恢复不会出现设置与课程各写入一半的状态。最后页面仍由 SharedPreferences 保存。无既有用户数据需要迁移。

## 待确认项

- 川大 GPA 官方规则及适用学年；当前可替换示例策略。
- 真实教学周、上课时间；由用户在界面自行设置，初始数据为示例。
- 正式包名、发布签名、隐私条款与分发渠道。
- 有授权、稳定的校园和志愿服务接口；当前没有账号或接口凭据。
- 真机、多厂商、API 24 设备的运行与系统文件选择器兼容性。

后续任务按依赖排列于 [开发清单](DEVELOPMENT_BACKLOG.md)。
