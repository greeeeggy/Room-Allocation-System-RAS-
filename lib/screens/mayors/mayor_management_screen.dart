import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mayor_provider.dart';
import '../../models/mayor_approval_model.dart';

class MayorManagementScreen extends ConsumerWidget {
  const MayorManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final approvalsAsync = ref.watch(myDepartmentApprovalsProvider);

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authorized Mayors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Mayor',
            onPressed: () => _showAddDialog(context, ref, user.department, user.userId),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.primary.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.business, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Managing: ${user.department}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: approvalsAsync.when(
              data: (approvals) {
                if (approvals.isEmpty) {
                  return const _EmptyState();
                }
                
                // Sort by section name
                final sorted = [...approvals]..sort((a, b) => a.courseSection.compareTo(b.courseSection));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _MayorApprovalCard(approval: sorted[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref, user.department, user.userId),
        icon: const Icon(Icons.person_add),
        label: const Text('Authorize Mayor'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, String dept, String userId) {
    showDialog(
      context: context,
      builder: (context) => _AddMayorDialog(department: dept, councilPresidentId: userId),
    );
  }
}

class _MayorApprovalCard extends ConsumerWidget {
  final MayorApprovalModel approval;
  const _MayorApprovalCard({required this.approval});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.school, color: Colors.white, size: 20),
        ),
        title: Text(
          approval.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(approval.courseSection),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context, ref, approval),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MayorApprovalModel approval) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Authorization?'),
        content: Text('This will prevent ${approval.name} from registering as the mayor of ${approval.courseSection}. Existing accounts will not be deleted but they may lose access to management features if you remove this.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(mayorServiceProvider).deleteApproval(approval.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddMayorDialog extends ConsumerStatefulWidget {
  final String department;
  final String councilPresidentId;
  const _AddMayorDialog({required this.department, required this.councilPresidentId});

  @override
  ConsumerState<_AddMayorDialog> createState() => _AddMayorDialogState();
}

class _AddMayorDialogState extends ConsumerState<_AddMayorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(mayorServiceProvider).addApproval(
            name: _nameCtrl.text.trim(),
            department: widget.department,
            courseSection: _sectionCtrl.text.trim().toUpperCase(),
            councilPresidentId: widget.councilPresidentId,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Authorize New Mayor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Mayor Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sectionCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Course & Section (e.g. BSIE 2-E)',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Department: ${widget.department}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No mayors authorized yet'),
          const SizedBox(height: 8),
          Text(
            'Tap + to authorize a mayor for your department',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
