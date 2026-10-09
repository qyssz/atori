"""Convert the observed teaching-system callback JSON to Atori course JSON.

Only timetable fields are retained; this script never copies student IDs,
account fields, cookies, tokens, or the original response into the project.
"""
import argparse
import json
import re
import uuid
from collections import Counter
from pathlib import Path


def integer(value, label):
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f'{label} must be an integer')
    return value


def text(value, label):
    if value is None:
        return ''
    if not isinstance(value, str):
        raise ValueError(f'{label} must be text')
    return value.strip()


def minute_clock(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}', value):
        raise ValueError('Section time must use HHmm')
    hour, minute = int(value[:2]), int(value[2:])
    if hour > 23 or minute > 59:
        raise ValueError('Invalid section time')
    return f'{hour:02}:{minute:02}', hour * 60 + minute


def convert(source):
    maps = source.get('xkxx')
    if not isinstance(maps, list) or not maps:
        raise ValueError('Expected a non-empty xkxx list')
    records = []
    for mapping in maps:
        if not isinstance(mapping, dict):
            raise ValueError('xkxx entries must be course maps')
        records.extend(mapping.values())
    courses, unarranged = [], []
    expected, actual = Counter(), Counter()
    palette = ['#6C7CDB', '#4A9B8E', '#CB8A5C', '#AA74B0', '#759C52', '#5698C4']
    meeting_count = 0
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError('Invalid course record')
        name = text(record.get('courseName'), 'courseName')
        if not name:
            raise ValueError('Missing courseName')
        meetings = record.get('timeAndPlaceList')
        if not isinstance(meetings, list):
            raise ValueError('timeAndPlaceList must be an array')
        if not meetings:
            unarranged.append(name)
        for meeting in meetings:
            meeting_count += 1
            day = integer(meeting.get('classDay'), 'classDay')
            start = integer(meeting.get('classSessions'), 'classSessions')
            length = integer(meeting.get('continuingSession'), 'continuingSession')
            end = start + length - 1
            if not 1 <= day <= 7 or not 1 <= start <= end <= 24 or length < 1:
                raise ValueError('Invalid weekday or section range')
            mask = text(meeting.get('classWeek'), 'classWeek')
            if not re.fullmatch(r'[01]{1,52}', mask) or '1' not in mask:
                raise ValueError('Missing or invalid classWeek mask')
            weeks = [i + 1 for i, bit in enumerate(mask) if bit == '1']
            teacher = text(meeting.get('courseTeacher'), 'courseTeacher') or text(
                record.get('attendClassTeacher'), 'attendClassTeacher')
            campus = text(meeting.get('campusName'), 'campusName')
            building = text(meeting.get('teachingBuildingName'), 'teachingBuildingName')
            room = text(meeting.get('classroomName'), 'classroomName')
            places = list(dict.fromkeys(p for p in [campus, building, room] if p))
            location = ' · '.join(places)
            for week in weeks:
                expected[(name, teacher, location, day, start, end, week)] += 1
            ranges = []
            first = previous = weeks[0]
            for week in weeks[1:]:
                if week != previous + 1:
                    ranges.append((first, previous))
                    first = week
                previous = week
            ranges.append((first, previous))
            note = '教务导出；原教学周：' + text(meeting.get('weekDescription'), 'weekDescription')
            for first, last in ranges:
                courses.append({
                    'id': str(uuid.uuid4()), 'name': name, 'teacher': teacher,
                    'location': location, 'weekday': day, 'startSection': start,
                    'endSection': end, 'startWeek': first, 'endWeek': last,
                    'weekType': 'all', 'color': palette[index % len(palette)], 'note': note,
                })
                for week in range(first, last + 1):
                    actual[(name, teacher, location, day, start, end, week)] += 1
    if actual != expected:
        raise ValueError('Converted teaching weeks do not match the original mask')
    raw_times = source.get('jcsjbs')
    if not isinstance(raw_times, list) or not 1 <= len(raw_times) <= 24:
        raise ValueError('Expected 1-24 section times')
    times = []
    previous_end = -1
    for index, item in enumerate(sorted(raw_times, key=lambda t: int(t['jc']))):
        if int(item['jc']) != index + 1:
            raise ValueError('Section indices must start at 1 without gaps')
        start, start_minutes = minute_clock(item['kssj'])
        end, end_minutes = minute_clock(item['jssj'])
        if not previous_end <= start_minutes < end_minutes:
            raise ValueError('Section times overlap or are reversed')
        times.append(f'{start}-{end}')
        previous_end = end_minutes
    if any(c['endSection'] > len(times) for c in courses):
        raise ValueError('Course exceeds supplied section times')
    return {'version': 1, 'courses': courses}, times, {
        'sourceCourses': len(records), 'sourceMeetings': meeting_count,
        'importRecords': len(courses), 'scheduledCourses': len(records) - len(unarranged),
        'unarrangedCourses': unarranged, 'verifiedOccurrences': sum(expected.values()),
        'maximumWeek': max(c['endWeek'] for c in courses),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input', type=Path)
    args = parser.parse_args()
    source = json.loads(args.input.read_text(encoding='utf-8-sig'))
    courses, times, summary = convert(source)
    output = Path(__file__).resolve().parent.parent / 'imports'
    output.mkdir(exist_ok=True)
    contents = {
        'atori-timetable.json': json.dumps(courses, ensure_ascii=False, indent=2) + '\n',
        'section-times.txt': '\n'.join(times) + '\n',
        'conversion-summary.json': json.dumps(summary, ensure_ascii=False, indent=2) + '\n',
    }
    if any((output / name).exists() for name in contents):
        raise FileExistsError('Converted files already exist; choose a fresh output before rerunning.')
    for name, content in contents.items():
        (output / name).write_text(content, encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False))
    print('Output:', output)


if __name__ == '__main__':
    main()
