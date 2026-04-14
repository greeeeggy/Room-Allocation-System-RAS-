import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mayor_service.dart';
import '../models/mayor_approval_model.dart';
import 'auth_provider.dart';

final mayorServiceProvider = Provider<MayorService>((ref) => MayorService());

/// Stream of authorized mayors for the logged-in Council President's department.
final myDepartmentApprovalsProvider = StreamProvider<List<MayorApprovalModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !user.isCouncilPresident) return const Stream.empty();
  
  return ref.watch(mayorServiceProvider).getApprovalsStream(user.department);
});
