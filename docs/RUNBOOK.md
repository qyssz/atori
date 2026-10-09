# 运行、构建与验证说明

以下命令在 PowerShell 的项目根目录执行。MVP 无需账号或环境密钥。

## 当前机器直接使用

```powershell
& ./scripts/check-environment.ps1 -FlutterRoot 'D:/atori-sdk/flutter' -AndroidSdkRoot 'D:/atori-sdk/android' -JavaHome 'D:/编程/jdk' -MinimumAndroidApi 36 -Json
& ./scripts/run-flutter.ps1 -Action doctor
& ./scripts/run-flutter.ps1 -Action check
& ./scripts/run-flutter.ps1 -Action build-apk -Clean
```

check 会格式化原目录 lib/test，复制到英文工作目录，再执行 pub get、format、analyze、test。build-apk 执行 release 构建并将成功 APK 复制回项目。-Clean 仅清理构建副本中的 Flutter 产物，不删除业务文件。

辅助脚本默认 SDK 根 D:/atori-sdk、JDK D:/编程/jdk，均可通过 -SdkRoot、-JavaHome 指定。英文构建目录名为 atori-workspace，缓存和临时文件同盘，不修改系统持久环境变量。不得同时启动两个会同步/修改同一构建副本的脚本。

## 另一台 Windows 机器准备环境

```powershell
& ./scripts/install-flutter.ps1 -SdkRoot 'D:/atori-sdk'
# 阅读并接受 Android SDK 许可证后执行；Java 路径改成实际已安装 JDK
& ./scripts/install-android.ps1 -SdkRoot 'D:/atori-sdk' -JavaHome 'D:/编程/jdk' -AcceptLicenses
& ./scripts/prepare-gradle.ps1 -SdkRoot 'D:/atori-sdk'
& ./scripts/run-flutter.ps1 -Action doctor -SdkRoot 'D:/atori-sdk' -JavaHome 'D:/编程/jdk'
```

安装脚本需要网络和目标目录写权限。Flutter 通过官方发行元数据选择 stable 并校验 SHA256；本次版本是 3.47.7。若之后 stable 变化，请按本次版本记录复现并核对 SDK/Gradle 模板兼容性。install-android 优先使用传入 JDK；没有传入时尝试下载 JDK17。当前 Gradle9.3.1 已使用 Java25.0.4.1 验证。

Android 组件包含 platform-tools、platforms/android-36、build-tools/36.0.0、ndk/28.2.13676358，以及部分插件使用的 platforms/android-35 和 cmake/3.22.1。新 android.exe CLI 用斜杠标识组件；旧 sdkmanager 兼容路径用分号。

prepare-gradle 仅用于网络阻塞官方发行下载时，镜像压缩包必须与官方 SHA256 完全相符。run-flutter 在英文构建副本中临时使用该本地文件，原始 Gradle 配置仍指向官方地址。校验不一致即终止。

官方参考：[Flutter 安装](https://docs.flutter.dev/install/manual)、[Android 环境](https://docs.flutter.dev/platform-integration/android/setup)、[Flutter CLI](https://docs.flutter.dev/reference/flutter-cli)。

## 启动源码

标准环境直接运行：

```powershell
flutter pub get
flutter devices
flutter run -d emulator-5556
```

当前中文目录若触发工具错误，先运行 run-flutter 的 prepare，然后在英文副本运行：

```powershell
& ./scripts/run-flutter.ps1 -Action prepare
$env:PUB_CACHE = 'D:/atori-sdk/pub-cache'
$env:GRADLE_USER_HOME = 'D:/atori-sdk/gradle-cache'
$env:TEMP = 'D:/atori-sdk/temp'
$env:TMP = $env:TEMP
$env:ANDROID_HOME = 'D:/atori-sdk/android'
$env:JAVA_HOME = 'D:/编程/jdk'
Push-Location 'D:/atori-sdk/atori-workspace'
try { & 'D:/atori-sdk/flutter/bin/flutter.bat' run -d emulator-5556 } finally { Pop-Location }
```

代码修改在原项目目录完成，重新 prepare 后生效；不要在副本里维护另一套源码。

## 模拟器与 APK 安装

可使用已有真机或模拟器。当前任务附带的模拟器脚本下载官方 API36 google_apis x86_64 镜像，不修改 Windows 虚拟化设置：

```powershell
& ./scripts/prepare-emulator.ps1 -JavaHome 'D:/编程/jdk'
& 'D:/atori-sdk/android/platform-tools/adb.exe' devices -l
& 'D:/atori-sdk/android/platform-tools/adb.exe' -s emulator-5556 shell getprop sys.boot_completed
& 'D:/atori-sdk/android/platform-tools/adb.exe' -s emulator-5556 install -r './build/app/outputs/flutter-apk/app-release.apk'
& 'D:/atori-sdk/android/platform-tools/adb.exe' -s emulator-5556 shell am start -n com.example.atori/.MainActivity
```

boot_completed 应为 1 后再安装。-r 更新安装保留应用数据；签名不一致的已有版本不能直接更新，应先备份，不要为绕过错误自动卸载。

实体手机可以直接打开 APK 安装，或启用 USB 调试后将设备 ID 替换为实际目标。最低 Android7.0；此 APK 使用开发签名，不用于商店发布。

## 验证

```powershell
& ./scripts/run-flutter.ps1 -Action check
python ./scripts/tests/test_environment.py
Get-FileHash -Algorithm SHA256 -LiteralPath './build/app/outputs/flutter-apk/app-release.apk'
```

当前 Flutter 测试 27 项，覆盖模型、单双周、冲突、成绩/GPA/学分/及格率、CSV、JSON、ICS、失败写入、并发设置、真实 Hive 文件重开、导航、CRUD、主题和布局。环境脚本另有 6 项文件布局测试。

设备验收步骤：

1. 启动检查四栏、示例周课表及课程详情。
2. 添加课程、修改、删除；另留一门自录课程，force-stop 后再启动确认仍存在。
3. 录入 95 分/4 学分、80 分/2 学分，筛选该学期，确认加权平均 90。
4. 检查成绩属性/学期筛选、GPA 排除开关和分析页。
5. 浏览第二课堂与志愿活动详情、状态筛选；已完成记录才计入获得分数与时长。
6. 切换深色和主题色，重新打开确认保持设置。
7. 导入 examples 文件、取消导入、导出备份、恢复备份；失败文件不改变原数据。
8. 清活动缓存保持课程/成绩；取消删除确认不删数据；测试全部删除时先备份。
9. 观察窄屏、键盘显示、重叠课程及文件选择器；日志中不得有 AndroidRuntime 启动崩溃。

## 常见故障

| 现象 | 处理 |
|---|---|
| 找不到 Flutter / SDK | 使用显式 SDK 路径，先 doctor，不以 PATH 未设置断言未安装 |
| Pub 跨卷重命名失败 | PUB_CACHE 与 TEMP/TMP 位于同一 D: SDK 根 |
| 中文路径 analyzer 协议错误 | 用 run-flutter 英文构建副本 |
| Gradle 下载跳转失败 | prepare-gradle 校验后使用本地 archive |
| NDK/CMake 包未找到 | 按具体缺失版本用新 android.exe sdk install 安装；不要只看泛化的 Java 提示 |
| 首次启动只显示加载/重试 | 检查应用私有存储与初始化日志，不自动清用户数据 |
| ICS 导出拒绝 | 先配置第一周的周一、足够周数和节次时间 |
| 减少周数/节次数后保存失败 | 先修改超出范围的现有课程，校验保护其不被静默截断 |
| 导入 CSV 失败 | UTF-8、正确表头/引号、有效范围；见 DATA_FORMAT |
