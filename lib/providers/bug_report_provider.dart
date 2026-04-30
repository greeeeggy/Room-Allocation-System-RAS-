import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bug_report_model.dart';
import '../services/bug_report_service.dart';

final bugReportServiceProvider =
    Provider<BugReportService>((ref) => BugReportService());

final allBugReportsProvider = StreamProvider<List<BugReportModel>>((ref) {
  final service = ref.watch(bugReportServiceProvider);
  return service.allBugReports();
});

final myBugReportsProvider = StreamProvider.family<List<BugReportModel>, String>((ref, userId) {
  final service = ref.watch(bugReportServiceProvider);
  return service.myBugReports(userId);
});
