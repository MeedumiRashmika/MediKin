import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';

import '../services/notification_service.dart';

class VisitDetailsScreen extends StatefulWidget {
  final String memberId;

  final String memberName;

  final String visitId;

  const VisitDetailsScreen({
    super.key,

    required this.memberId,

    required this.memberName,

    required this.visitId,
  });

  @override
  State<VisitDetailsScreen> createState() => _VisitDetailsScreenState();
}

class _VisitDetailsScreenState extends State<VisitDetailsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _visitDocument {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not signed in.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(widget.memberId)
        .collection('visits')
        .doc(widget.visitId);
  }

  CollectionReference<Map<String, dynamic>> get _medicinesCollection {
    return _visitDocument.collection('medicines');
  }

  // ============================================================

  // PRESCRIPTION NOTES

  // ============================================================

  Future<void> _showPrescriptionForm(String currentNotes) async {
    final controller = TextEditingController(text: currentNotes);

    bool isSaving = false;

    await showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> savePrescription() async {
              setModalState(() => isSaving = true);

              try {
                await _visitDocument.update({
                  'prescriptionNotes': controller.text.trim(),

                  'prescriptionUpdatedAt': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;

                Navigator.pop(context);

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Prescription notes saved.'),

                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (_) {
                if (!context.mounted) return;

                setModalState(() => isSaving = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to save prescription.'),

                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return _BottomSheetContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const _SheetHandle(),

                  const SizedBox(height: 22),

                  const Row(
                    children: [
                      _SmallIconBox(
                        icon: Icons.description_outlined,

                        backgroundColor: AppColors.primaryVeryLight,

                        iconColor: AppColors.primary,
                      ),

                      SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              'Prescription Notes',

                              style: TextStyle(
                                fontSize: 21,

                                fontWeight: FontWeight.w700,

                                color: AppColors.darkText,
                              ),
                            ),

                            SizedBox(height: 3),

                            Text(
                              'Record the doctor’s prescription instructions.',

                              style: TextStyle(
                                fontSize: 13,

                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  TextField(
                    controller: controller,

                    minLines: 5,

                    maxLines: 9,

                    textCapitalization: TextCapitalization.sentences,

                    decoration: const InputDecoration(
                      hintText: 'Enter prescription notes...',

                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,

                    height: 54,

                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : savePrescription,

                      icon: isSaving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.check_rounded),

                      label: isSaving
                          ? const SizedBox(
                              width: 23,

                              height: 23,

                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,

                                color: AppColors.white,
                              ),
                            )
                          : const Text(
                              'Save Prescription',

                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================

  // ADD / EDIT MEDICINE + REMINDERS

  // ============================================================

  Future<void> _showMedicineForm({
    String? medicineId,

    Map<String, dynamic>? existingData,
  }) async {
    final bool isEditing = medicineId != null;

    final nameController = TextEditingController(
      text: existingData?['name']?.toString() ?? '',
    );

    final dosageController = TextEditingController(
      text: existingData?['dosage']?.toString() ?? '',
    );

    final instructionsController = TextEditingController(
      text: existingData?['instructions']?.toString() ?? '',
    );

    DateTime startDate = DateTime.now();

    if (existingData?['startDate'] is Timestamp) {
      startDate = (existingData!['startDate'] as Timestamp).toDate();
    }

    final durationController = TextEditingController(
      text: (existingData?['durationDays'] ?? 7).toString(),
    );

    bool reminderEnabled = existingData?['reminderEnabled'] == true;

    final List<TimeOfDay> reminderTimes = [];

    final existingTimes = existingData?['reminderTimes'];

    if (existingTimes is List) {
      for (final item in existingTimes) {
        final parsed = _parseStoredTime(item.toString());

        if (parsed != null) {
          reminderTimes.add(parsed);
        }
      }
    }

    bool isSaving = false;

    await showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickStartDate() async {
              final picked = await showDatePicker(
                context: context,

                initialDate: startDate,

                firstDate: DateTime.now().subtract(const Duration(days: 365)),

                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );

              if (picked != null) {
                setModalState(() => startDate = picked);
              }
            }

            Future<void> addReminderTime() async {
              final picked = await showTimePicker(
                context: context,

                initialTime: TimeOfDay.now(),
              );

              if (picked == null) return;

              final duplicate = reminderTimes.any(
                (time) =>
                    time.hour == picked.hour && time.minute == picked.minute,
              );

              if (duplicate) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This reminder time is already added.'),

                    behavior: SnackBarBehavior.floating,
                  ),
                );

                return;
              }

              setModalState(() {
                reminderTimes.add(picked);

                reminderTimes.sort(
                  (a, b) => (a.hour * 60 + a.minute).compareTo(
                    b.hour * 60 + b.minute,
                  ),
                );
              });
            }

            Future<void> saveMedicine() async {
              final name = nameController.text.trim();

              final dosage = dosageController.text.trim();

              final instructions = instructionsController.text.trim();

              final durationDays = int.tryParse(durationController.text.trim());

              if (name.isEmpty) {
                _showSheetMessage(context, 'Please enter the medicine name.');

                return;
              }

              if (durationDays == null || durationDays <= 0) {
                _showSheetMessage(
                  context,

                  'Please enter a valid duration in days.',
                );

                return;
              }

              // V1 safety limit: prevents hundreds of pending alarms.

              if (durationDays > 30) {
                _showSheetMessage(
                  context,

                  'For now, medicine reminders can be scheduled for up to 30 days.',
                );

                return;
              }

              if (reminderEnabled && reminderTimes.isEmpty) {
                _showSheetMessage(
                  context,

                  'Please add at least one reminder time.',
                );

                return;
              }

              setModalState(() => isSaving = true);

              try {
                final oldIds = _readNotificationIds(existingData);

                if (oldIds.isNotEmpty) {
                  await NotificationService.instance.cancelMedicineReminders(
                    oldIds,
                  );
                }

                final data = <String, dynamic>{
                  'name': name,

                  'dosage': dosage,

                  'startDate': Timestamp.fromDate(
                    DateTime(startDate.year, startDate.month, startDate.day),
                  ),

                  'durationDays': durationDays,

                  // Keep a readable duration field for older UI/data compatibility.
                  'duration': '$durationDays days',

                  'frequency': reminderEnabled
                      ? '${reminderTimes.length} time${reminderTimes.length == 1 ? '' : 's'} a day'
                      : '',

                  'instructions': instructions,

                  'reminderEnabled': reminderEnabled,

                  'reminderTimes': reminderTimes
                      .map(_storeTime)
                      .toList(growable: false),

                  'notificationIds': <int>[],

                  'updatedAt': FieldValue.serverTimestamp(),
                };

                late final DocumentReference<Map<String, dynamic>> medicineRef;

                if (isEditing) {
                  medicineRef = _medicinesCollection.doc(medicineId);

                  await medicineRef.update(data);
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();

                  medicineRef = await _medicinesCollection.add(data);
                }

                List<int> notificationIds = [];

                if (reminderEnabled) {
                  final reminderDateTimes = reminderTimes
                      .map(
                        (time) => DateTime(2000, 1, 1, time.hour, time.minute),
                      )
                      .toList();

                  final baseNotificationId = _notificationBaseId(
                    medicineRef.id,
                  );

                  notificationIds = await NotificationService.instance
                      .scheduleMedicineCourse(
                        medicineName: name,

                        dosage: dosage,

                        startDate: startDate,

                        durationDays: durationDays,

                        reminderTimes: reminderDateTimes,

                        baseNotificationId: baseNotificationId,
                      );
                }

                await medicineRef.update({
                  'notificationIds': notificationIds,

                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;

                Navigator.pop(context);

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      reminderEnabled
                          ? (notificationIds.isEmpty
                                ? 'Medicine saved. No future reminder times were available to schedule.'
                                : 'Medicine saved and ${notificationIds.length} reminder(s) scheduled.')
                          : (isEditing
                                ? 'Medicine updated.'
                                : 'Medicine added.'),
                    ),

                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                setModalState(() => isSaving = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to save medicine: $e'),

                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return _BottomSheetContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const _SheetHandle(),

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Container(
                        width: 48,

                        height: 48,

                        decoration: BoxDecoration(
                          color: AppColors.warningLight,

                          borderRadius: BorderRadius.circular(15),
                        ),

                        child: Icon(
                          isEditing
                              ? Icons.edit_outlined
                              : Icons.medication_outlined,

                          color: const Color(0xFFC28A00),
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Medicine' : 'Add Medicine',

                          style: const TextStyle(
                            fontSize: 21,

                            fontWeight: FontWeight.w700,

                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  const _FieldLabel('Medicine name'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: nameController,

                    textCapitalization: TextCapitalization.words,

                    decoration: const InputDecoration(
                      hintText: 'Example: Amoxicillin',

                      prefixIcon: Icon(Icons.medication_outlined),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const _FieldLabel('Dosage'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: dosageController,

                    decoration: const InputDecoration(
                      hintText: 'Example: 500 mg / 1 tablet',

                      prefixIcon: Icon(Icons.science_outlined),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const _FieldLabel('Start date'),

                  const SizedBox(height: 8),

                  InkWell(
                    onTap: pickStartDate,

                    borderRadius: BorderRadius.circular(14),

                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_outlined),

                        suffixIcon: Icon(Icons.chevron_right_rounded),
                      ),

                      child: Text(
                        _formatDate(startDate),

                        style: const TextStyle(
                          fontWeight: FontWeight.w600,

                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const _FieldLabel('Duration (days)'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: durationController,

                    keyboardType: TextInputType.number,

                    decoration: const InputDecoration(
                      hintText: 'Example: 7',

                      prefixIcon: Icon(Icons.date_range_outlined),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: AppColors.white,

                      borderRadius: BorderRadius.circular(16),

                      border: Border.all(color: AppColors.border),
                    ),

                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,

                          value: reminderEnabled,

                          activeThumbColor: AppColors.primary,

                          title: const Text(
                            'Medicine reminders',

                            style: TextStyle(
                              fontWeight: FontWeight.w700,

                              color: AppColors.darkText,
                            ),
                          ),

                          subtitle: const Text(
                            'Get a notification when it is time to take this medicine.',
                          ),

                          secondary: const Icon(
                            Icons.notifications_active_outlined,

                            color: AppColors.primary,
                          ),

                          onChanged: (value) {
                            setModalState(() => reminderEnabled = value);
                          },
                        ),

                        if (reminderEnabled) ...[
                          const Divider(height: 24),

                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Reminder times',

                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,

                                    color: AppColors.darkText,
                                  ),
                                ),
                              ),

                              TextButton.icon(
                                onPressed: addReminderTime,

                                icon: const Icon(Icons.add_alarm_outlined),

                                label: const Text('Add Time'),
                              ),
                            ],
                          ),

                          if (reminderTimes.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,

                              child: Padding(
                                padding: EdgeInsets.only(top: 6),

                                child: Text(
                                  'No reminder times added yet.',

                                  style: TextStyle(
                                    fontSize: 12,

                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 8),

                              child: Wrap(
                                spacing: 8,

                                runSpacing: 8,

                                children: reminderTimes.map((time) {
                                  return InputChip(
                                    avatar: const Icon(
                                      Icons.schedule_outlined,

                                      size: 18,
                                    ),

                                    label: Text(_formatTime(context, time)),

                                    onDeleted: () {
                                      setModalState(() {
                                        reminderTimes.remove(time);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const _FieldLabel('Instructions'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: instructionsController,

                    minLines: 2,

                    maxLines: 4,

                    textCapitalization: TextCapitalization.sentences,

                    decoration: const InputDecoration(
                      hintText: 'Example: Take after meals',
                    ),
                  ),

                  const SizedBox(height: 27),

                  SizedBox(
                    width: double.infinity,

                    height: 54,

                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : saveMedicine,

                      icon: isSaving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.check_rounded),

                      label: isSaving
                          ? const SizedBox(
                              width: 23,

                              height: 23,

                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,

                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Add Medicine',

                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================

  // DELETE MEDICINE

  // ============================================================

  Future<void> _deleteMedicine(
    String medicineId,

    String medicineName,

    Map<String, dynamic> medicineData,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete medicine?'),

          content: Text(
            'Remove $medicineName from this prescription? Its scheduled reminders will also be cancelled.',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),

              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),

              child: const Text(
                'Delete',

                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final notificationIds = _readNotificationIds(medicineData);

      if (notificationIds.isNotEmpty) {
        await NotificationService.instance.cancelMedicineReminders(
          notificationIds,
        );
      }

      await _medicinesCollection.doc(medicineId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine and its reminders were deleted.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete medicine: $e'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================

  // HELPERS

  // ============================================================

  List<int> _readNotificationIds(Map<String, dynamic>? data) {
    final raw = data?['notificationIds'];

    if (raw is! List) return [];

    return raw
        .map((item) {
          if (item is int) return item;

          return int.tryParse(item.toString());
        })
        .whereType<int>()
        .toList();
  }

  int _notificationBaseId(String medicineId) {
    // Keep IDs positive and leave room for multiple reminders per medicine.

    return (medicineId.hashCode.abs() % 10000000) * 100;
  }

  String _storeTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  TimeOfDay? _parseStoredTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  void _showSheetMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================

  // BUILD

  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit Details')),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _visitDocument.snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load visit.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('This visit no longer exists.'));
          }

          final visit = snapshot.data!.data()!;

          final doctorName = visit['doctorName']?.toString() ?? 'Doctor';

          final reason = visit['reason']?.toString() ?? '';

          final notes = visit['notes']?.toString() ?? '';

          final prescriptionNotes =
              visit['prescriptionNotes']?.toString() ?? '';

          DateTime? visitDate;

          DateTime? nextVisitDate;

          if (visit['visitDate'] is Timestamp) {
            visitDate = (visit['visitDate'] as Timestamp).toDate();
          }

          if (visit['nextVisitDate'] is Timestamp) {
            nextVisitDate = (visit['nextVisitDate'] as Timestamp).toDate();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 35),

            children: [
              // VISIT HEADER

              Container(
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: AppColors.primary,

                  borderRadius: BorderRadius.circular(24),
                ),

                child: Row(
                  children: [
                    Container(
                      width: 60,

                      height: 60,

                      decoration: BoxDecoration(
                        color: AppColors.white,

                        borderRadius: BorderRadius.circular(18),
                      ),

                      child: const Icon(
                        Icons.local_hospital_outlined,

                        color: AppColors.primary,

                        size: 29,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            doctorName,

                            style: const TextStyle(
                              fontSize: 19,

                              fontWeight: FontWeight.w800,

                              color: AppColors.white,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            widget.memberName,

                            style: TextStyle(
                              fontSize: 13,

                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),

                          if (visitDate != null) ...[
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                const Icon(
                                  Icons.event_outlined,

                                  size: 14,

                                  color: AppColors.white,
                                ),

                                const SizedBox(width: 5),

                                Text(
                                  _formatDate(visitDate),

                                  style: const TextStyle(
                                    fontSize: 12,

                                    fontWeight: FontWeight.w600,

                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 27),

              const _SectionTitle(title: 'Visit Information'),

              const SizedBox(height: 13),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(17),

                  child: Column(
                    children: [
                      _InformationRow(
                        icon: Icons.description_outlined,

                        label: 'Reason for visit',

                        value: reason.isEmpty ? 'Not added' : reason,
                      ),

                      const Divider(height: 28),

                      _InformationRow(
                        icon: Icons.notes_rounded,

                        label: 'Notes',

                        value: notes.isEmpty ? 'Not added' : notes,
                      ),

                      const Divider(height: 28),

                      _InformationRow(
                        icon: Icons.event_repeat_outlined,

                        label: 'Next recommended visit',

                        value: nextVisitDate == null
                            ? 'Not scheduled'
                            : _formatDate(nextVisitDate),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // PRESCRIPTION
              Row(
                children: [
                  const Expanded(child: _SectionTitle(title: 'Prescription')),

                  TextButton.icon(
                    onPressed: () {
                      _showPrescriptionForm(prescriptionNotes);
                    },

                    icon: Icon(
                      prescriptionNotes.isEmpty
                          ? Icons.add_rounded
                          : Icons.edit_outlined,

                      size: 18,
                    ),

                    label: Text(prescriptionNotes.isEmpty ? 'Add' : 'Edit'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(17),

                  child: prescriptionNotes.isEmpty
                      ? const Row(
                          children: [
                            _SmallIconBox(
                              icon: Icons.description_outlined,

                              backgroundColor: AppColors.primaryVeryLight,

                              iconColor: AppColors.primary,
                            ),

                            SizedBox(width: 13),

                            Expanded(
                              child: Text(
                                'No prescription notes added yet.',

                                style: TextStyle(
                                  fontSize: 13,

                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const _SmallIconBox(
                              icon: Icons.description_outlined,

                              backgroundColor: AppColors.primaryVeryLight,

                              iconColor: AppColors.primary,
                            ),

                            const SizedBox(width: 13),

                            Expanded(
                              child: Text(
                                prescriptionNotes,

                                style: const TextStyle(
                                  fontSize: 13,

                                  height: 1.5,

                                  color: AppColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // MEDICINES
              Row(
                children: [
                  const Expanded(child: _SectionTitle(title: 'Medicines')),

                  TextButton.icon(
                    onPressed: () => _showMedicineForm(),

                    icon: const Icon(Icons.add_rounded, size: 18),

                    label: const Text('Add'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _medicinesCollection
                    .orderBy('createdAt', descending: false)
                    .snapshots(),

                builder: (context, medicineSnapshot) {
                  if (medicineSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(25),

                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (medicineSnapshot.hasError) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),

                        child: Text(
                          'Unable to load medicines.',

                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    );
                  }

                  final medicines = medicineSnapshot.data?.docs ?? [];

                  if (medicines.isEmpty) {
                    return Card(
                      child: InkWell(
                        onTap: () => _showMedicineForm(),

                        borderRadius: BorderRadius.circular(20),

                        child: const Padding(
                          padding: EdgeInsets.all(18),

                          child: Row(
                            children: [
                              _SmallIconBox(
                                icon: Icons.medication_outlined,

                                backgroundColor: AppColors.warningLight,

                                iconColor: Color(0xFFC28A00),
                              ),

                              SizedBox(width: 13),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      'No medicines added',

                                      style: TextStyle(
                                        fontSize: 14,

                                        fontWeight: FontWeight.w700,

                                        color: AppColors.darkText,
                                      ),
                                    ),

                                    SizedBox(height: 3),

                                    Text(
                                      'Tap here to add the first medicine.',

                                      style: TextStyle(
                                        fontSize: 12,

                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Icon(
                                Icons.add_circle_outline_rounded,

                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: medicines.map((document) {
                      final data = document.data();

                      final name = data['name']?.toString() ?? 'Medicine';

                      final dosage = data['dosage']?.toString() ?? '';

                      final instructions =
                          data['instructions']?.toString() ?? '';

                      final reminderEnabled = data['reminderEnabled'] == true;

                      final durationDays =
                          int.tryParse(
                            data['durationDays']?.toString() ?? '',
                          ) ??
                          0;

                      DateTime? startDate;

                      if (data['startDate'] is Timestamp) {
                        startDate = (data['startDate'] as Timestamp).toDate();
                      }

                      final storedTimes = data['reminderTimes'] is List
                          ? List<String>.from(
                              (data['reminderTimes'] as List).map(
                                (e) => e.toString(),
                              ),
                            )
                          : <String>[];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 11),

                        child: _MedicineCard(
                          name: name,

                          dosage: dosage,

                          startDate: startDate,

                          durationDays: durationDays,

                          instructions: instructions,

                          reminderEnabled: reminderEnabled,

                          reminderTimes: storedTimes,

                          onEdit: () {
                            _showMedicineForm(
                              medicineId: document.id,

                              existingData: data,
                            );
                          },

                          onDelete: () {
                            _deleteMedicine(document.id, name, data);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================

// MEDICINE CARD

// =============================================================

class _MedicineCard extends StatelessWidget {
  final String name;

  final String dosage;

  final DateTime? startDate;

  final int durationDays;

  final String instructions;

  final bool reminderEnabled;

  final List<String> reminderTimes;

  final VoidCallback onEdit;

  final VoidCallback onDelete;

  const _MedicineCard({
    required this.name,

    required this.dosage,

    required this.startDate,

    required this.durationDays,

    required this.instructions,

    required this.reminderEnabled,

    required this.reminderTimes,

    required this.onEdit,

    required this.onDelete,
  });

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _displayStoredTime(BuildContext context, String stored) {
    final parts = stored.split(':');

    if (parts.length != 2) return stored;

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return stored;

    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const _SmallIconBox(
              icon: Icons.medication_outlined,

              backgroundColor: AppColors.warningLight,

              iconColor: Color(0xFFC28A00),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    name,

                    style: const TextStyle(
                      fontSize: 15,

                      fontWeight: FontWeight.w700,

                      color: AppColors.darkText,
                    ),
                  ),

                  if (dosage.isNotEmpty) ...[
                    const SizedBox(height: 6),

                    Text(
                      dosage,

                      style: const TextStyle(
                        fontSize: 12,

                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],

                  if (startDate != null || durationDays > 0) ...[
                    const SizedBox(height: 6),

                    Text(
                      [
                        if (startDate != null) 'Start: ${_date(startDate!)}',

                        if (durationDays > 0)
                          '$durationDays day${durationDays == 1 ? '' : 's'}',
                      ].join(' • '),

                      style: const TextStyle(
                        fontSize: 12,

                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        reminderEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,

                        size: 16,

                        color: reminderEnabled
                            ? AppColors.primary
                            : AppColors.secondaryText,
                      ),

                      const SizedBox(width: 5),

                      Expanded(
                        child: Text(
                          reminderEnabled
                              ? (reminderTimes.isEmpty
                                    ? 'Reminders on'
                                    : reminderTimes
                                          .map(
                                            (time) => _displayStoredTime(
                                              context,

                                              time,
                                            ),
                                          )
                                          .join(' • '))
                              : 'Reminders off',

                          style: TextStyle(
                            fontSize: 12,

                            fontWeight: reminderEnabled
                                ? FontWeight.w600
                                : FontWeight.w400,

                            color: reminderEnabled
                                ? AppColors.primary
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,

                        vertical: 7,
                      ),

                      decoration: BoxDecoration(
                        color: AppColors.primaryVeryLight,

                        borderRadius: BorderRadius.circular(9),
                      ),

                      child: Text(
                        instructions,

                        style: const TextStyle(
                          fontSize: 11,

                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();

                if (value == 'delete') onDelete();
              },

              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: 'edit',

                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 19),

                        SizedBox(width: 10),

                        Text('Edit'),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: 'delete',

                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,

                          size: 19,

                          color: AppColors.error,
                        ),

                        SizedBox(width: 10),

                        Text(
                          'Delete',

                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================

// INFORMATION ROW

// =============================================================

class _InformationRow extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;

  const _InformationRow({
    required this.icon,

    required this.label,

    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 20, color: AppColors.primary),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                label,

                style: const TextStyle(
                  fontSize: 11,

                  color: AppColors.secondaryText,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                value,

                style: const TextStyle(
                  fontSize: 14,

                  height: 1.4,

                  fontWeight: FontWeight.w600,

                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================

// SECTION TITLE

// =============================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,

      style: const TextStyle(
        fontSize: 19,

        fontWeight: FontWeight.w700,

        color: AppColors.darkText,
      ),
    );
  }
}

// =============================================================

// SMALL ICON

// =============================================================

class _SmallIconBox extends StatelessWidget {
  final IconData icon;

  final Color backgroundColor;

  final Color iconColor;

  const _SmallIconBox({
    required this.icon,

    required this.backgroundColor,

    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,

      height: 46,

      decoration: BoxDecoration(
        color: backgroundColor,

        borderRadius: BorderRadius.circular(14),
      ),

      child: Icon(icon, size: 23, color: iconColor),
    );
  }
}

// =============================================================

// FIELD LABEL

// =============================================================

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,

      style: const TextStyle(
        fontSize: 14,

        fontWeight: FontWeight.w600,

        color: AppColors.darkText,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,

        height: 5,

        decoration: BoxDecoration(
          color: AppColors.border,

          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _BottomSheetContainer extends StatelessWidget {
  final Widget child;

  const _BottomSheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),

      decoration: const BoxDecoration(
        color: AppColors.background,

        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      padding: EdgeInsets.fromLTRB(
        22,

        12,

        22,

        MediaQuery.of(context).viewInsets.bottom + 24,
      ),

      child: SingleChildScrollView(child: child),
    );
  }
}
