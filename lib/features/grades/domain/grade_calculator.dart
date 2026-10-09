import 'dart:math' as math;

import '../../../shared/models/models.dart';

abstract interface class GpaStrategy {
  String get label;
  double scoreToGpa(double score);
}

class ExampleFourPointStrategy implements GpaStrategy {
  const ExampleFourPointStrategy();
  @override
  String get label => '示例 4.0 制（非川大官方）';
  @override
  double scoreToGpa(double score) {
    if (!score.isFinite || score < 0 || score > 100) {
      throw const FormatException('成绩范围无效');
    }
    return score < 60 ? 0 : math.min(4, (score - 50) / 10).toDouble();
  }
}

class GradeCalculator {
  GradeCalculator(
    Iterable<Grade> values, {
    this.strategy = const ExampleFourPointStrategy(),
  }) : grades = List.unmodifiable(values) {
    for (final g in grades) {
      g.validate();
    }
  }
  final List<Grade> grades;
  final GpaStrategy strategy;
  double calculateAverage() => grades.isEmpty
      ? 0
      : grades.fold<double>(0, (s, g) => s + g.score) / grades.length;
  double calculateWeightedAverage() {
    final credits = grades.fold<double>(0, (s, g) => s + g.credit);
    return credits == 0
        ? 0
        : grades.fold<double>(0, (s, g) => s + g.score * g.credit) / credits;
  }

  double calculateGpa() {
    final included = grades.where((g) => g.includedInGpa && g.credit > 0);
    final credits = included.fold<double>(0, (s, g) => s + g.credit);
    return credits == 0
        ? 0
        : included.fold<double>(
                0,
                (s, g) => s + strategy.scoreToGpa(g.score) * g.credit,
              ) /
              credits;
  }

  double calculatePassRate() => grades.isEmpty
      ? 0
      : grades.where((g) => g.score >= 60).length / grades.length * 100;
  double calculateTotalCredits() => grades
      .where((g) => g.score >= 60)
      .fold<double>(0, (s, g) => s + g.credit);
  bool get hasWeightedData => grades.any((g) => g.credit > 0);
  bool get hasGpaData => grades.any((g) => g.includedInGpa && g.credit > 0);
  List<int> distribution() => [
    grades.where((g) => g.score >= 90).length,
    grades.where((g) => g.score >= 80 && g.score < 90).length,
    grades.where((g) => g.score >= 70 && g.score < 80).length,
    grades.where((g) => g.score >= 60 && g.score < 70).length,
    grades.where((g) => g.score < 60).length,
  ];
}
