import 'package:expense_tracker/features/reports/domain/financial_report.dart';
import 'package:expense_tracker/features/reports/presentation/report_view_model.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/material.dart';
import 'package:expense_tracker/core/providers/appearance_provider.dart';

List<Override> emptyReportOverrides() => [
  appearanceProvider.overrideWith((ref) => Stream.value(ThemeMode.system)),
  financialReportProvider.overrideWith(
    (ref, period) => Stream.value(FinancialReport.calculate(period, const [])),
  ),
];
