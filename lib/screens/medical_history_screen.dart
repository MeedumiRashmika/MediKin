import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';
import 'visit_details_screen.dart';

class MedicalHistoryScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const MedicalHistoryScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<_HistoryItem> _items = [];

  CollectionReference<Map<String, dynamic>> get _memberCollection {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User is not signed in.');

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers');
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final member = _memberCollection.doc(widget.memberId);

      final results = await Future.wait([
        member.collection('visits').get(),
        member.collection('labReports').get(),
      ]);

      final visits = results[0];
      final reports = results[1];
      final items = <_HistoryItem>[];

      for (final visit in visits.docs) {
        final data = visit.data();
        final visitDate = _timestampDate(data['visitDate']);
        if (visitDate == null) continue;

        final doctorName =
            _text(data['doctorName']).isEmpty ? 'Doctor visit' : _text(data['doctorName']);
        final reason = _text(data['reason']);
        final notes = _text(data['notes']);

        final medicineSnapshot = await visit.reference.collection('medicines').get();
        final medicineNames = medicineSnapshot.docs
            .map((doc) => _text(doc.data()['name']))
            .where((name) => name.isNotEmpty)
            .toList();

        final detailParts = <String>[
          if (reason.isNotEmpty) reason,
          if (medicineNames.isNotEmpty) 'Medicines: ${medicineNames.join(', ')}',
          if (notes.isNotEmpty) notes,
        ];

        items.add(
          _HistoryItem(
            type: _HistoryType.visit,
            date: visitDate,
            title: doctorName,
            subtitle: detailParts.isEmpty
                ? 'Doctor visit'
                : detailParts.join(' • '),
            visitId: visit.id,
          ),
        );
      }

      for (final report in reports.docs) {
        final data = report.data();
        final reportDate = _timestampDate(data['reportDate']);
        if (reportDate == null) continue;

        final reportName = _text(data['reportName']).isEmpty
            ? 'Lab Report'
            : _text(data['reportName']);
        final laboratory = _text(data['laboratory']);
        final doctorName = _text(data['doctorName']);
        final notes = _text(data['notes']);

        final detailParts = <String>[
          if (laboratory.isNotEmpty) laboratory,
          if (doctorName.isNotEmpty) 'Doctor: $doctorName',
          if (notes.isNotEmpty) notes,
        ];

        items.add(
          _HistoryItem(
            type: _HistoryType.labReport,
            date: reportDate,
            title: reportName,
            subtitle: detailParts.isEmpty
                ? 'Lab report'
                : detailParts.join(' • '),
          ),
        );
      }

      items.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn’t load medical history.';
        _loading = false;
      });
    }
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static DateTime? _timestampDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static String _date(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Future<void> _openItem(_HistoryItem item) async {
    if (item.type == _HistoryType.visit && item.visitId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisitDetailsScreen(
            memberId: widget.memberId,
            memberName: widget.memberName,
            visitId: item.visitId!,
          ),
        ),
      );
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadHistory)
              : _items.isEmpty
                  ? _EmptyState(memberName: widget.memberName)
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                        children: [
                          Text(
                            '${widget.memberName}\'s Health Timeline',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Doctor visits, medicines and lab reports in one place.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 22),
                          ..._items.map(_historyCard),
                        ],
                      ),
                    ),
    );
  }

  Widget _historyCard(_HistoryItem item) {
    final isVisit = item.type == _HistoryType.visit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          onTap: isVisit ? () => _openItem(item) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isVisit
                        ? AppColors.primaryVeryLight
                        : AppColors.successLight,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    isVisit
                        ? Icons.local_hospital_outlined
                        : Icons.science_outlined,
                    color: isVisit ? AppColors.primary : AppColors.success,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _date(item.date),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isVisit ? 'Doctor Visit' : 'Lab Report',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isVisit ? AppColors.primary : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.subtitle,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isVisit) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _HistoryType { visit, labReport }

class _HistoryItem {
  final _HistoryType type;
  final DateTime date;
  final String title;
  final String subtitle;
  final String? visitId;

  const _HistoryItem({
    required this.type,
    required this.date,
    required this.title,
    required this.subtitle,
    this.visitId,
  });
}

class _EmptyState extends StatelessWidget {
  final String memberName;

  const _EmptyState({required this.memberName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 105,
              height: 105,
              decoration: BoxDecoration(
                color: AppColors.primaryVeryLight,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No medical history yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visits and lab reports saved for $memberName will appear here automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
