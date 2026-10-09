# MVP 开发与交付记录

日期：2026-10-09（Asia/Shanghai）。依据：PROJECT_SPEC.md。

## 本轮结果

用户先确认项目梳理范围，随后要求“开始”“按md文件制作”。本轮由原先只有需求文档的目录完成 Flutter Android MVP；原始规格保留。未接入真实校园服务。随后按用户要求上传至 GitHub 公开仓库，并发布体验版 APK。

已交付源码、四份独立 Mock 资源、27项 Flutter 测试、工具链与构建脚本、格式样例、运行及后续开发文档，以及可安装 Release APK。

## 产物

| 项目 | 实际结果 |
|---|---|
| APK | [下载 app-release.apk](https://github.com/qyssz/atori/releases/download/v1.0.0/app-release.apk)；本地：`build/app/outputs/flutter-apk/app-release.apk` |
| 文件字节数 | 56,364,215（构建显示53.8MB） |
| SHA256 | `f4deeebdd816133f515a5874d69cff6af48b530cc6b834d72854c91eac82a3b9` |
| 应用 / 包名 | 亚托莉 / com.example.atori |
| 版本 | 1.0.0，versionCode1 |
| 最低 / 目标 Android | API24（Android7.0）/ API36 |
| 签名 | 开发证书 Android Debug，apksigner verify 通过，v2 签名 |
| 实测设备 | 专用 API36 / Android16 x86_64 模拟器 emulator-5556 |
| 实体手机 | 未连接，未做真机测试 |

APK 使用 release 编译配置和开发签名，已通过 GitHub Release 提供体验下载。应用商店正式发布另需永久包名和发布密钥。

## GitHub 交付

- 公开仓库：[qyssz/atori](https://github.com/qyssz/atori)，默认分支 `main`。
- 源码基线：`ccf4f44a368f2b79f70046a3d820264eacbd8900`；Release 标签为 `v1.0.0`。
- [v1.0.0 Release](https://github.com/qyssz/atori/releases/tag/v1.0.0) 已公开，包含 APK 和 `SHA256SUMS.txt`。
- GitHub 返回的 APK 大小为 56,364,215 字节，SHA256 与本地构建产物一致。
- 提交使用 GitHub 隐私邮箱。公开文件未检出个人学号或凭据；真实教务响应、个人转换结果、设备备份、SDK 和签名私钥均未上传。

## 修改与实现

1. Material3、Riverpod、go_router 工程、四栏导航、全页面路由、浅/深色与系统主题。
2. Course、Timetable、Grade、Activity、Settings 模型及严格类型/范围/关联校验。
3. Hive 单快照、Mock 数据源、Repository、串行 Controller，成功保存后发布新状态。SharedPreferences 记录最后底部页面。
4. 完整周课表、课程 CRUD/详情、多课表与学期设置、单双周和冲突提醒。重叠课程自动扩宽以保持可点击。
5. 成绩 CRUD、筛选、GPA开关、独立计算策略、加权统计与分析。
6. 第二课堂/志愿列表、统计、详情、状态筛选及可用的空/加载/错误反馈；所有数据为标明的本地示例。
7. 主题色、卡片样式、教师/教室显示、作息编辑、清缓存与确认后删除全部数据。
8. 实际系统文件选择器导入导出、JSON/CSV、ICS、version1完整备份及原子恢复。
9. 课程/成绩样例文件，工具链准备和中文路径构建副本脚本；更新 README、现状、清单、运行、格式说明。

## 已执行检查

| 检查 | 结果 |
|---|---|
| Flutter / Android doctor | Flutter 和 Android toolchain 通过；SDK许可证已处理 |
| 真实环境预检查 | 显式 SDK 路径，MinimumAndroidApi36；preflightPassed=true，退出0 |
| dart format | lib/test 格式化完成；最终检查无新增格式变更 |
| flutter analyze | No issues found，退出0 |
| flutter test | **27项全部通过**：22项领域/文件交换/存储、5项界面回归 |
| 诊断脚本回归 | **6项全部通过**，只使用临时模拟工具文件 |
| flutter clean | 在英文构建副本执行成功 |
| flutter build apk --release | 成功，assembleRelease 275.2秒 |
| apksigner verify | 通过，确认开发签名 |
| aapt manifest 检查 | app名称/包名/版本/API符合记录；没有 INTERNET 或全盘存储权限 |
| PowerShell 脚本解析 | 全部通过 |
| Markdown | 本地链接与代码块完整性检查通过 |

合并 manifest 中有 AndroidX 内部 DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION，用于限制内部接收器。当前 MVP 没有真实网络访问。

首次构建曾因未安装 NDK失败，已用新版 Android CLI补齐。构建过程自动安装插件需要的 Android35和CMake3.22.1，安装脚本也已加入对应组件。Java原生访问和SDK XML版本提示未影响本次成功构建，未隐藏这些输出。

## 第一阶段验收对应

| 需求 | 验证证据与结果 |
|---|---|
| Android可安装 | adb install -r 返回 Success |
| 可启动、无启动崩溃 | am start 成功、进程存在、实际课表截图；AndroidRuntime/flutter错误日志未见启动异常 |
| 四栏导航 | widget测试和安装APK实际四页切换通过 |
| 查看周课表 | 实际截图、教学周切换与单双周领域测试通过 |
| 手动增加、修改、删除课程 | widget CRUD通过；模拟器添加 AtoriSmoke、改为AtoriSmokeEdited、删除成功 |
| 关闭后课程存在 | force-stop→重新启动→全新UI层级中确认AtoriSmoke；随后清理该测试课程 |
| 查看成绩 | 安装APK显示5条初始成绩；录入/导入界面可用 |
| 加权平均、GPA、学分统计 | 计算单元测试通过；设备导入95分/4学分、80分/2学分后显示90.00、通过6.0学分 |
| 成绩筛选 | 设备按“导入验收”学期筛选出2门；widget/领域测试覆盖GPA排除与计算 |
| 第二课堂与志愿页完整 | 列表、详情、筛选、完成统计与我的入口；widget测试和设备截图 |
| 深色正常 | 全主要路由浅/深色回归通过；设备切换后重启仍为深色 |
| 无明显UI溢出 | 320px窄屏、20门重叠课程回归通过；设备实际截图检查 |
| analyze无严重错误 | No issues found |
| Release APK成功 | 构建成功及签名验证通过 |

补充设备验收：

- 系统文件保存完整备份到 Downloads，拉取 JSON并确认6门课程、5条成绩和完整顶层字段。
- 通过系统选择器导入课程 JSON和成绩 CSV；预览确认后追加成功。
- 恢复导出的原备份，课程/成绩从追加状态恢复至6门/5条，原始ID随备份保留。
- 最后页面为“我的”时强制关闭，重新启动恢复“我的”；深色模式偏好同时保留。

UI层级每次使用新文件名并等待捕获成功，避免启动尚未完成时误读旧文件。设备行为证据保存在本地 artifacts/，其中仅有示例和本轮测试数据。

## 实际界面

- [浅色课表](images/timetable.png)
- [深色课表](images/dark-timetable.png)
- [成绩](images/grades.png)
- [第二课堂](images/second-class.png)
- [志愿四川](images/volunteer.png)
- [导入成绩后的90.00结果](images/filtered-grades.png)
- [Android系统保存选择器](images/export-picker.png)

## 与需求建议的差异

- 最低API采用24，因为当前 Flutter stable 的模板最低值为24；没有声称支持API23。
- 设置和业务数据一起保存为Hive快照，以保障整批恢复一致；SharedPreferences保存最后页面。
- 小规模工程将路由与主题置于app.dart，第二课堂/志愿共用展示组件，减少重复。
- TimetableImporter 方法命名 importCourses；Dart 的 import 是保留关键字，不能按需求示意直接作方法名。
- GPA为可替换的示例4.0策略，未使用未经核实的学校公式。

## 已知限制和后续工作

当前活动状态为固定示例，不是真实报名；不支持校园登录、真实教务同步或ICS导入。默认校历及节次为可修改示例，活动时间按设备当地时区显示；测试模拟器已设为Asia/Shanghai。首次使用真实数据前应调整学期和作息。

未验证实体手机、API24实际设备、所有厂商文件管理器或高字体缩放；这些列入下一批R01。GitHub main 分支与 v1.0.0 Release 已交付，个人导入、设备缓存和签名文件被忽略。正式签名、官方GPA和接口资料仍待确认，详细实施与验收见 [后续开发清单](DEVELOPMENT_BACKLOG.md)。

使用与复现见 [README](../README.md)、[RUNBOOK](RUNBOOK.md)、[数据格式](DATA_FORMAT.md)。
