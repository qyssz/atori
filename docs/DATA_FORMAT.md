# 导入、导出与备份格式

## 通用约定

文本文件使用 UTF-8，可有 BOM；最大导入文件 20 MB。JSON 数值不能用字符串替代，布尔只能为 true/false。未知备份版本、无效范围或数据类型均拒绝。

普通课程/成绩导入是**追加**，导入前显示数量并确认。为每条记录生成新 UUID，原 id 被忽略；课程全部归入当前选中的课表。重复导入会产生另一批记录，不自动按名称去重。学期、周数和节次设置不会被普通导入覆盖。

完整备份恢复是**替换**，保留原记录 ID、所有课表及所选课表。先验证全文件再确认并保存为一个 Hive 快照，失败时仍保留原数据。

## 课程 JSON

接受课程数组，或 `{"version":1,"courses":[...]}`。应用导出还包含 timetable 对象，普通导入只取 courses。

必填：name、weekday、startSection、endSection、startWeek、endWeek。weekday 为1–7；节次1–24且不能超过现有节次数量；教学周1–52且不能超过当前课表总周数；起点不大于终点。可选 teacher/location/note 默认空字符串，weekType 为 all/odd/even，color 为 #RRGGBB。

样例：[courses.json](../examples/courses.json)。导入前将当前课表设为至少20周、2节。

## 课程 CSV

必需表头：

```csv
name,weekday,startSection,endSection,startWeek,endWeek
```

可选：teacher,location,weekType,color,note。表头顺序任意；不能重复；每行列数与表头一致。含逗号/换行的值用双引号包裹，内部双引号写为两个双引号。样例：[courses.csv](../examples/courses.csv)。

## 成绩 JSON / CSV

JSON 接受数组或 `{"version":1,"grades":[...]}`。必填 courseName、score、credit；分数和学分为有限数值0–100。semester 默认空、courseType 默认必修、includedInGpa 默认 true。

CSV 必需表头 courseName,score,credit；可选 semester,courseType,includedInGpa（true/false，不使用0/1）。

样例：[grades.csv](../examples/grades.csv)。95分×4学分和80分×2学分的加权平均为90。可选导出已存全部成绩，不按当前筛选缩减。

## 完整备份 version1

顶层：version、createdAt、timetables、selectedTimetableId、courses、grades、secondClass、volunteer、settings。

- timetables 包含 id、name、weeks、startDate（空或 YYYY-MM-DD 的周一）。
- courses 保留 id 和 timetableId；所有引用必须存在，ID 在各集合内唯一。
- 活动保存开始/结束时间与状态；第二课堂可选 registrationStart/registrationEnd，须成对且顺序正确；旧文件缺省为空。
- settings 含 theme、seedColor、showTeacher、showLocation、cardRadius、cardOpacity、sectionTimes。
- sectionTimes 为1–24节 HH:mm 起止，必须按时间排列且不重叠。
- 包含课程、成绩及偏好；没有密码、Token、Cookie 或真实账号凭据。
- 最后一个底部页面是设备偏好，由 SharedPreferences 保存，不包含在业务备份中。

建议从 App 导出备份后编辑，以保留正确的 ID 和设置字段。恢复新字段缺省兼容已有 version1，但未知 version 被拒绝。

## ICS

仅支持导出当前课表，暂不支持 ICS 导入。须先设置第一教学周的周一和节次作息。按每个有效教学周及单双周生成独立 VEVENT；课程配置按中国标准时间 UTC+8 解释，转为 UTC 的 DTSTART/DTEND。

支持文本转义、稳定课程/周 UID、UTF-8 75字节折行。不会包含不属于当前课表的课程。初始节次是通用样例，请调整后用于真实日历。
