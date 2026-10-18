import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';
import 'visit_details_screen.dart';

class MedicinesScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const MedicinesScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _visitsCollection {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not signed in.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(widget.memberId)
        .collection('visits');
  }

  Future<List<_MedicineRecord>> _loadMedicines() async {
    final visitsSnapshot = await _visitsCollection
        .orderBy('visitDate', descending: true)
        .get();

    final List<_MedicineRecord> records = [];

    for (final visitDocument in visitsSnapshot.docs) {
      final visitData = visitDocument.data();
      final doctorName = visitData['doctorName']?.toString().trim() ?? 'Doctor';

      DateTime? visitDate;
      if (visitData['visitDate'] is Timestamp) {
        visitDate = (visitData['visitDate'] as Timestamp).toDate();
      }

      final medicinesSnapshot = await visitDocument.reference
          .collection('medicines')
          .orderBy('createdAt', descending: false)
          .get();

      for (final medicineDocument in medicinesSnapshot.docs) {
        final medicineData = medicineDocument.data();

        DateTime? startDate;
        if (medicineData['startDate'] is Timestamp) {
          startDate = (medicineData['startDate'] as Timestamp).toDate();
        }

        final reminderTimes = medicineData['reminderTimes'] is List
            ? (medicineData['reminderTimes'] as List)
                  .map((item) => item.toString())
                  .toList()
            : <String>[];

        records.add(
          _MedicineRecord(
            visitId: visitDocument.id,
            medicineId: medicineDocument.id,
            doctorName: doctorName.isEmpty ? 'Doctor' : doctorName,
            visitDate: visitDate,
            name: medicineData['name']?.toString().trim().isNotEmpty == true
                ? medicineData['name'].toString().trim()
                : 'Medicine',
            dosage: medicineData['dosage']?.toString().trim() ?? '',
            startDate: startDate,
            durationDays:
                int.tryParse(medicineData['durationDays']?.toString() ?? '') ??
                0,
            instructions: medicineData['instructions']?.toString().trim() ?? '',
            reminderEnabled: medicineData['reminderEnabled'] == true,
            reminderTimes: reminderTimes,
          ),
        );
      }
    }

    records.sort((a, b) {
      final aDate = a.startDate ?? a.visitDate ?? DateTime(1970);
      final bDate = b.startDate ?? b.visitDate ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return records;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _displayStoredTime(String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return stored;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return stored;

    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
  }

  Future<void> _openVisit(_MedicineRecord medicine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitDetailsScreen(
          memberId: widget.memberId,
          memberName: widget.memberName,
          visitId: medicine.visitId,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicines')),
      body: FutureBuilder<List<_MedicineRecord>>(
        future: _loadMedicines(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load medicines',
              message: 'Please check your connection and try again.',
              actionLabel: 'Try Again',
              onAction: () => setState(() {}),
            );
          }

          final medicines = snapshot.data ?? [];

          if (medicines.isEmpty) {
            return _MessageState(
              icon: Icons.medication_outlined,
              title: 'No medicines yet',
              message:
                  'Medicines added to ${widget.memberName}\'s doctor visits will appear here.',
              actionLabel: 'Refresh',
              onAction: () => setState(() {}),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primaryVeryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.medication_outlined,
                          color: AppColors.primary,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.memberName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${medicines.length} medicine${medicines.length == 1 ? '' : 's'} across doctor visits',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'All Medicines',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 12),
                ...medicines.map(
                  (medicine) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        onTap: () => _openVisit(medicine),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.warningLight,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.medication_outlined,
                                      color: Color(0xFFC28A00),
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          medicine.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        if (medicine.dosage.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            medicine.dosage,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.secondaryText,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _InfoLine(
                                icon: Icons.medical_services_outlined,
                                text: medicine.doctorName,
                              ),
                              if (medicine.visitDate != null)
                                _InfoLine(
                                  icon: Icons.event_outlined,
                                  text:
                                      'Visit: ${_formatDate(medicine.visitDate!)}',
                                ),
                              if (medicine.startDate != null ||
                                  medicine.durationDays > 0)
                                _InfoLine(
                                  icon: Icons.date_range_outlined,
                                  text: [
                                    if (medicine.startDate != null)
                                      'Start ${_formatDate(medicine.startDate!)}',
                                    if (medicine.durationDays > 0)
                                      '${medicine.durationDays} day${medicine.durationDays == 1 ? '' : 's'}',
                                  ].join(' • '),
                                ),
                              _InfoLine(
                                icon: medicine.reminderEnabled
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_off_outlined,
                                text: medicine.reminderEnabled
                                    ? (medicine.reminderTimes.isEmpty
                                          ? 'Reminders on'
                                          : medicine.reminderTimes
                                                .map(_displayStoredTime)
                                                .join(' • '))
                                    : 'Reminders off',
                                highlight: medicine.reminderEnabled,
                              ),
                              if (medicine.instructions.isNotEmpty) ...[
                                const SizedBox(height: 9),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryVeryLight,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Text(
                                    medicine.instructions,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.darkText,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              const Text(
                                'Tap to open the related visit',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MedicineRecord {
  final String visitId;
  final String medicineId;
  final String doctorName;
  final DateTime? visitDate;
  final String name;
  final String dosage;
  final DateTime? startDate;
  final int durationDays;
  final String instructions;
  final bool reminderEnabled;
  final List<String> reminderTimes;

  const _MedicineRecord({
    required this.visitId,
    required this.medicineId,
    required this.doctorName,
    required this.visitDate,
    required this.name,
    required this.dosage,
    required this.startDate,
    required this.durationDays,
    required this.instructions,
    required this.reminderEnabled,
    required this.reminderTimes,
  });
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _InfoLine({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight ? AppColors.primary : AppColors.secondaryText,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                color: highlight ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryVeryLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
