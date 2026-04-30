import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/bug_report_model.dart';
import '../../providers/bug_report_provider.dart';

class SubmittedBugsScreen extends ConsumerStatefulWidget {
  const SubmittedBugsScreen({super.key});
  @override
  ConsumerState<SubmittedBugsScreen> createState() => _SubmittedBugsScreenState();
}

class _SubmittedBugsScreenState extends ConsumerState<SubmittedBugsScreen> {
  String _filter = 'ALL';
  static const _filters = ['ALL', 'OPEN', 'IN PROGRESS', 'RESOLVED'];

  @override
  Widget build(BuildContext context) {
    final bugsAsync = ref.watch(allBugReportsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SUBMITTED', style: GoogleFonts.outfit(color: const Color(0xFF00D4AA), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 6)),
                  const SizedBox(height: 2),
                  Text('BUG REPORTS', style: GoogleFonts.outfit(color: const Color(0xFF1A1A1A), fontSize: 32, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -1)),
                ],
              ),
            ),
            // Filter tabs
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _filters.map((f) {
                  final sel = _filter == f;
                  final c = f == 'OPEN' ? const Color(0xFF00D4AA) : f == 'IN PROGRESS' ? const Color(0xFFFFB74D) : f == 'RESOLVED' ? const Color(0xFF757575) : AppColors.primary;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6, bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: sel ? c : Colors.white, border: Border.all(color: sel ? c : Colors.black.withOpacity(0.06))),
                      child: Center(child: Text(f, style: TextStyle(color: sel ? Colors.white : Colors.black45, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            // Bug list
            Expanded(
              child: bugsAsync.when(
                data: (bugs) {
                  final filtered = _filter == 'ALL' ? bugs : bugs.where((b) => b.status == (_filter == 'OPEN' ? BugStatus.open : _filter == 'IN PROGRESS' ? BugStatus.inProgress : BugStatus.resolved)).toList();
                  if (filtered.isEmpty) return _EmptyBugs(filter: _filter);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _BugCard(bug: filtered[i], index: i, onTap: () => _showDetail(filtered[i]), onDelete: () => _delete(filtered[i].reportId)),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00D4AA))),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BugReportModel bug) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _BugDetailSheet(bug: bug, onStatusChange: (s) => _updateStatus(bug.reportId, s)));
  }

  Future<void> _updateStatus(String id, BugStatus s) async {
    try { await ref.read(bugReportServiceProvider).updateStatus(id, s); } catch (_) {}
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst || !Navigator.of(context).canPop());
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text('Delete Bug Report', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
      content: Text('Permanently delete this report?', style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('DELETE', style: TextStyle(color: Colors.red.shade700)))],
    ));
    if (ok == true) await ref.read(bugReportServiceProvider).deleteReport(id);
  }
}

// ── Bug Card ──
class _BugCard extends StatelessWidget {
  final BugReportModel bug;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _BugCard({required this.bug, required this.index, required this.onTap, required this.onDelete});

  Color _color() => bug.status == BugStatus.open ? const Color(0xFF00D4AA) : bug.status == BugStatus.inProgress ? const Color(0xFFFFB74D) : const Color(0xFF757575);
  String _label() => bug.status == BugStatus.open ? 'OPEN' : bug.status == BugStatus.inProgress ? 'IN PROGRESS' : 'RESOLVED';
  String _ago() { final d = DateTime.now().difference(bug.createdAt); return d.inDays > 0 ? '${d.inDays}d ago' : d.inHours > 0 ? '${d.inHours}h ago' : d.inMinutes > 0 ? '${d.inMinutes}m ago' : 'Just now'; }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 80).clamp(0, 500)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 15 * (1 - v)), child: child)),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onDelete,
        child: SizedBox(
          height: 110,
          child: Stack(children: [
            Positioned.fill(child: Container(
              decoration: BoxDecoration(color: const Color(0xFFF1F1F1), border: Border.all(color: Colors.black.withOpacity(0.08)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))]),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.bug_report_rounded, color: c, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(bug.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('${bug.submitterName} · ${bug.roleLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_ago(), style: TextStyle(color: Colors.black.withOpacity(0.25), fontSize: 9, fontWeight: FontWeight.w600)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.1), border: Border.all(color: c.withOpacity(0.3))), child: Text(_label(), style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))),
                  if (bug.imageBase64 != null) ...[const SizedBox(height: 8), Icon(Icons.image_outlined, size: 16, color: Colors.black.withOpacity(0.2))],
                ]),
              ]),
            )),
            Positioned(top: 0, left: 0, child: Container(width: 24, height: 2, color: c.withOpacity(0.4))),
            Positioned(top: 0, left: 0, child: Container(width: 2, height: 24, color: c.withOpacity(0.4))),
          ]),
        ),
      ),
    );
  }
}

// ── Detail Sheet ──
class _BugDetailSheet extends StatelessWidget {
  final BugReportModel bug;
  final ValueChanged<BugStatus> onStatusChange;
  const _BugDetailSheet({required this.bug, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(color: Color(0xFFFBFBFB)),
        child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(24, 16, 24, 40), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text(bug.title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A), letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('${bug.submitterName} · ${bug.roleLabel}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Text('DESCRIPTION', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black.withOpacity(0.06))), child: Text(bug.description, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF1A1A1A), height: 1.6))),
          if (bug.imageBase64 != null) ...[
            const SizedBox(height: 20),
            Text('ATTACHMENT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white), body: Center(child: InteractiveViewer(child: Image.memory(base64Decode(bug.imageBase64!))))))),
              child: Container(constraints: const BoxConstraints(maxHeight: 300), decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.06))), child: Image.memory(base64Decode(bug.imageBase64!), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(height: 100, child: Center(child: Icon(Icons.broken_image, color: Colors.grey))))),
            ),
          ],
          const SizedBox(height: 24),
          Text('UPDATE STATUS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
          const SizedBox(height: 8),
          Row(children: [
            _StatusBtn(label: 'OPEN', color: const Color(0xFF00D4AA), active: bug.status == BugStatus.open, onTap: () { onStatusChange(BugStatus.open); Navigator.pop(context); }),
            const SizedBox(width: 8),
            _StatusBtn(label: 'IN PROGRESS', color: const Color(0xFFFFB74D), active: bug.status == BugStatus.inProgress, onTap: () { onStatusChange(BugStatus.inProgress); Navigator.pop(context); }),
            const SizedBox(width: 8),
            _StatusBtn(label: 'RESOLVED', color: const Color(0xFF757575), active: bug.status == BugStatus.resolved, onTap: () { onStatusChange(BugStatus.resolved); Navigator.pop(context); }),
          ]),
        ]),
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label; final Color color; final bool active; final VoidCallback onTap;
  const _StatusBtn({required this.label, required this.color, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: active ? color : color.withOpacity(0.08), border: Border.all(color: color.withOpacity(0.3))),
    child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
  )));
}

// ── Empty ──
class _EmptyBugs extends StatelessWidget {
  final String filter;
  const _EmptyBugs({required this.filter});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.bug_report_outlined, size: 80, color: Colors.black.withOpacity(0.04)),
    const SizedBox(height: 20),
    Text(filter == 'ALL' ? 'NO BUG REPORTS YET' : 'NO $filter REPORTS', style: TextStyle(color: Colors.black.withOpacity(0.12), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
    const SizedBox(height: 4),
    Text(filter == 'ALL' ? 'Bug reports submitted by users will appear here.' : 'No bug reports with this status.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(0.08), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
  ]));
}
