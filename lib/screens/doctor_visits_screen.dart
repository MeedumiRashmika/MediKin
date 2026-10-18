import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';

import '../services/notification_service.dart';

import 'visit_details_screen.dart';

class DoctorVisitsScreen extends StatefulWidget {
  final String memberId;

  final String memberName;

  const DoctorVisitsScreen({
    super.key,

    required this.memberId,

    required this.memberName,
  });

  @override
  State<DoctorVisitsScreen> createState() => _DoctorVisitsScreenState();
}

class _DoctorVisitsScreenState extends State<DoctorVisitsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _memberCollection {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not signed in.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers');
  }

  CollectionReference<Map<String, dynamic>> get _visitsCollection {
    return _memberCollection.doc(widget.memberId).collection('visits');
  }

  CollectionReference<Map<String, dynamic>> get _doctorsCollection {
    return _memberCollection.doc(widget.memberId).collection('doctors');
  }

  // ============================================================

  // ADD / EDIT VISIT

  // ============================================================

  Future<void> _showVisitForm({
    String? visitId,

    Map<String, dynamic>? existingData,
  }) async {
    final bool isEditing = visitId != null;

    final reasonController = TextEditingController(
      text: existingData?['reason']?.toString() ?? '',
    );

    final notesController = TextEditingController(
      text: existingData?['notes']?.toString() ?? '',
    );

    DateTime visitDate = DateTime.now();

    DateTime? nextVisitDate;

    if (existingData?['visitDate'] is Timestamp) {
      visitDate = (existingData!['visitDate'] as Timestamp).toDate();
    }

    if (existingData?['nextVisitDate'] is Timestamp) {
      nextVisitDate = (existingData!['nextVisitDate'] as Timestamp).toDate();
    }

    String? selectedDoctorId = existingData?['doctorId']?.toString();

    String? selectedDoctorName = existingData?['doctorName']?.toString();

    bool isSaving = false;

    try {
      final doctorsSnapshot = await _doctorsCollection
          .orderBy('createdAt', descending: false)
          .get();

      if (!mounted) {
        return;
      }

      final doctors = doctorsSnapshot.docs;

      if (doctors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add a doctor before creating a visit.'),

            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      if (selectedDoctorId != null &&
          !doctors.any((doctor) => doctor.id == selectedDoctorId)) {
        selectedDoctorId = null;

        selectedDoctorName = null;
      }

      await showModalBottomSheet(
        context: context,

        isScrollControlled: true,

        backgroundColor: Colors.transparent,

        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> selectVisitDate() async {
                final pickedDate = await showDatePicker(
                  context: context,

                  initialDate: visitDate,

                  firstDate: DateTime(2000),

                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );

                if (pickedDate != null) {
                  setModalState(() {
                    visitDate = pickedDate;
                  });
                }
              }

              Future<void> selectNextVisitDate() async {
                final initialNextDate =
                    nextVisitDate ?? visitDate.add(const Duration(days: 30));

                final pickedDate = await showDatePicker(
                  context: context,

                  initialDate: initialNextDate,

                  firstDate: visitDate,

                  lastDate: DateTime(DateTime.now().year + 10),
                );

                if (pickedDate != null) {
                  setModalState(() {
                    nextVisitDate = pickedDate;
                  });
                }
              }

              Future<void> saveVisit() async {
                if (selectedDoctorId == null || selectedDoctorName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a doctor.'),

                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  return;
                }

                setModalState(() {
                  isSaving = true;
                });

                try {
                  DocumentReference<Map<String, dynamic>> visitReference;

                  List<int> oldVisitReminderIds = [];

                  if (isEditing) {
                    final oldSnapshot = await _visitsCollection
                        .doc(visitId)
                        .get();

                    final oldData = oldSnapshot.data();

                    if (oldData != null &&
                        oldData['visitReminderIds'] is List) {
                      oldVisitReminderIds =
                          (oldData['visitReminderIds'] as List)
                              .whereType<num>()
                              .map((id) => id.toInt())
                              .toList();
                    }

                    visitReference = _visitsCollection.doc(visitId);
                  } else {
                    visitReference = _visitsCollection.doc();
                  }

                  if (oldVisitReminderIds.isNotEmpty) {
                    await NotificationService.instance.cancelVisitReminders(
                      oldVisitReminderIds,
                    );
                  }

                  final baseNotificationId = _notificationBaseId(
                    visitReference.id,
                  );

                  List<int> visitReminderIds = [];

                  if (nextVisitDate != null) {
                    visitReminderIds = await NotificationService.instance
                        .scheduleVisitReminders(
                          memberName: widget.memberName,

                          doctorName: selectedDoctorName!,

                          visitDate: nextVisitDate!,

                          baseNotificationId: baseNotificationId,
                        );
                  }

                  final data = <String, dynamic>{
                    'doctorId': selectedDoctorId,

                    'doctorName': selectedDoctorName,

                    'visitDate': Timestamp.fromDate(visitDate),

                    'reason': reasonController.text.trim(),

                    'notes': notesController.text.trim(),

                    'nextVisitDate': nextVisitDate == null
                        ? null
                        : Timestamp.fromDate(nextVisitDate!),

                    'visitReminderIds': visitReminderIds,

                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (isEditing) {
                    await visitReference.update(data);
                  } else {
                    data['createdAt'] = FieldValue.serverTimestamp();

                    await visitReference.set(data);
                  }

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  if (!mounted) return;

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Doctor visit updated.'
                            : 'Doctor visit saved.',
                      ),

                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  setModalState(() {
                    isSaving = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to save the visit. Please try again.',
                      ),

                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }

              return Container(
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

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Center(
                        child: Container(
                          width: 42,

                          height: 5,

                          decoration: BoxDecoration(
                            color: AppColors.border,

                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Container(
                            width: 48,

                            height: 48,

                            decoration: BoxDecoration(
                              color: AppColors.primaryVeryLight,

                              borderRadius: BorderRadius.circular(15),
                            ),

                            child: Icon(
                              isEditing
                                  ? Icons.edit_calendar_outlined
                                  : Icons.add_task_rounded,

                              color: AppColors.primary,
                            ),
                          ),

                          const SizedBox(width: 13),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  isEditing
                                      ? 'Edit Doctor Visit'
                                      : 'Add Doctor Visit',

                                  style: const TextStyle(
                                    fontSize: 21,

                                    fontWeight: FontWeight.w700,

                                    color: AppColors.darkText,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  'Record a visit for ${widget.memberName}.',

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

                      const SizedBox(height: 27),

                      const _FieldLabel('Doctor'),

                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        initialValue: selectedDoctorId,

                        isExpanded: true,

                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.medical_services_outlined),

                          hintText: 'Select doctor',
                        ),

                        items: doctors.map((doctor) {
                          final doctorData = doctor.data();

                          final doctorName =
                              doctorData['name']?.toString() ?? 'Doctor';

                          final specialty =
                              doctorData['specialty']?.toString() ?? '';

                          return DropdownMenuItem<String>(
                            value: doctor.id,

                            child: Text(
                              specialty.isEmpty
                                  ? doctorName
                                  : '$doctorName • $specialty',

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),

                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;

                                final doctor = doctors.firstWhere(
                                  (doctor) => doctor.id == value,
                                );

                                setModalState(() {
                                  selectedDoctorId = value;

                                  selectedDoctorName =
                                      doctor.data()['name']?.toString() ??
                                      'Doctor';
                                });
                              },
                      ),

                      const SizedBox(height: 18),

                      const _FieldLabel('Visit date'),

                      const SizedBox(height: 8),

                      InkWell(
                        onTap: isSaving ? null : selectVisitDate,

                        borderRadius: BorderRadius.circular(14),

                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.event_outlined),

                            suffixIcon: Icon(Icons.calendar_month_outlined),
                          ),

                          child: Text(
                            _formatDate(visitDate),

                            style: const TextStyle(color: AppColors.darkText),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _FieldLabel('Reason for visit'),

                      const SizedBox(height: 8),

                      TextField(
                        controller: reasonController,

                        textCapitalization: TextCapitalization.sentences,

                        textInputAction: TextInputAction.next,

                        decoration: const InputDecoration(
                          hintText: 'Example: Routine check-up',

                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _FieldLabel('Notes'),

                      const SizedBox(height: 8),

                      TextField(
                        controller: notesController,

                        textCapitalization: TextCapitalization.sentences,

                        minLines: 3,

                        maxLines: 5,

                        decoration: const InputDecoration(
                          hintText: 'Add important notes from the visit',

                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _FieldLabel('Next recommended visit'),

                      const SizedBox(height: 8),

                      InkWell(
                        onTap: isSaving ? null : selectNextVisitDate,

                        borderRadius: BorderRadius.circular(14),

                        child: InputDecorator(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.event_repeat_outlined),

                            suffixIcon: nextVisitDate == null
                                ? const Icon(Icons.calendar_month_outlined)
                                : IconButton(
                                    onPressed: isSaving
                                        ? null
                                        : () {
                                            setModalState(() {
                                              nextVisitDate = null;
                                            });
                                          },

                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),

                          child: Text(
                            nextVisitDate == null
                                ? 'No date selected'
                                : _formatDate(nextVisitDate!),

                            style: TextStyle(
                              color: nextVisitDate == null
                                  ? AppColors.secondaryText
                                  : AppColors.darkText,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,

                        height: 54,

                        child: ElevatedButton.icon(
                          onPressed: isSaving ? null : saveVisit,

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
                                  isEditing ? 'Save Changes' : 'Save Visit',

                                  style: const TextStyle(
                                    fontSize: 16,

                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load doctors. Please try again.'),

            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ============================================================

  // DELETE VISIT

  // ============================================================

  Future<void> _deleteVisit(String visitId) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete visit?'),

          content: const Text(
            'Are you sure you want to delete this doctor visit?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

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
      final visitSnapshot = await _visitsCollection.doc(visitId).get();

      final visitData = visitSnapshot.data();

      if (visitData != null && visitData['visitReminderIds'] is List) {
        final reminderIds = (visitData['visitReminderIds'] as List)
            .whereType<num>()
            .map((id) => id.toInt())
            .toList();

        if (reminderIds.isNotEmpty) {
          await NotificationService.instance.cancelVisitReminders(reminderIds);
        }
      }

      // Delete all medicines saved under this visit first.
      // Firestore does not automatically delete subcollections when
      // the parent visit document is deleted.
      final medicinesCollection = _visitsCollection
          .doc(visitId)
          .collection('medicines');
      final medicinesSnapshot = await medicinesCollection.get();

      // Cancel medicine notifications before deleting medicine documents.
      for (final medicineDoc in medicinesSnapshot.docs) {
        final medicineData = medicineDoc.data();
        final rawNotificationIds = medicineData['notificationIds'];

        if (rawNotificationIds is List) {
          final notificationIds = rawNotificationIds
              .whereType<num>()
              .map((id) => id.toInt())
              .toList();

          if (notificationIds.isNotEmpty) {
            for (final notificationId in notificationIds) {
              await NotificationService.instance.cancelNotification(
                notificationId,
              );
            }
          }
        }
      }

      // Firestore batches support up to 500 writes. Delete in chunks so
      // this stays safe even if a visit has many medicine documents.
      const batchLimit = 450;
      for (
        var start = 0;
        start < medicinesSnapshot.docs.length;
        start += batchLimit
      ) {
        final batch = _firestore.batch();
        final end = (start + batchLimit < medicinesSnapshot.docs.length)
            ? start + batchLimit
            : medicinesSnapshot.docs.length;

        for (var i = start; i < end; i++) {
          batch.delete(medicinesSnapshot.docs[i].reference);
        }

        await batch.commit();
      }

      // Delete the visit only after its nested medicines are removed.
      await _visitsCollection.doc(visitId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor visit deleted.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete visit.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================

  // NOTIFICATION ID

  // ============================================================

  int _notificationBaseId(String visitId) {
    int hash = 0;

    for (final codeUnit in visitId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x3fffffff;
    }

    return 500000000 + (hash % 100000000);
  }

  // ============================================================

  // DATE

  // ============================================================

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================

  // BUILD

  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Visits')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showVisitForm();
        },

        icon: const Icon(Icons.add_rounded),

        label: const Text(
          'Add Visit',

          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _visitsCollection
            .orderBy('visitDate', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _VisitErrorState();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final visits = snapshot.data?.docs ?? [];

          if (visits.isEmpty) {
            return _EmptyVisitsState(
              memberName: widget.memberName,

              onAdd: () {
                _showVisitForm();
              },
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),

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
                        Icons.medical_information_outlined,

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
                            '${widget.memberName}\'s Visits',

                            style: const TextStyle(
                              fontSize: 17,

                              fontWeight: FontWeight.w700,

                              color: AppColors.darkText,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '${visits.length} '
                            '${visits.length == 1 ? 'visit' : 'visits'} recorded',

                            style: const TextStyle(
                              fontSize: 12,

                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 27),

              const Text(
                'Visit History',

                style: TextStyle(
                  fontSize: 19,

                  fontWeight: FontWeight.w700,

                  color: AppColors.darkText,
                ),
              ),

              const SizedBox(height: 14),

              ...visits.map((document) {
                final data = document.data();

                final doctorName = data['doctorName']?.toString() ?? 'Doctor';

                final reason = data['reason']?.toString() ?? '';

                DateTime? visitDate;

                DateTime? nextVisitDate;

                if (data['visitDate'] is Timestamp) {
                  visitDate = (data['visitDate'] as Timestamp).toDate();
                }

                if (data['nextVisitDate'] is Timestamp) {
                  nextVisitDate = (data['nextVisitDate'] as Timestamp).toDate();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),

                  child: _VisitCard(
                    doctorName: doctorName,

                    reason: reason,

                    visitDate: visitDate,

                    nextVisitDate: nextVisitDate,

                    // =================================

                    // OPEN VISIT DETAILS

                    // =================================
                    onTap: () {
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (context) => VisitDetailsScreen(
                            memberId: widget.memberId,

                            memberName: widget.memberName,

                            visitId: document.id,
                          ),
                        ),
                      );
                    },

                    onEdit: () {
                      _showVisitForm(visitId: document.id, existingData: data);
                    },

                    onDelete: () {
                      _deleteVisit(document.id);
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================

// VISIT CARD

// =============================================================

class _VisitCard extends StatelessWidget {
  final String doctorName;

  final String reason;

  final DateTime? visitDate;

  final DateTime? nextVisitDate;

  final VoidCallback onTap;

  final VoidCallback onEdit;

  final VoidCallback onDelete;

  const _VisitCard({
    required this.doctorName,

    required this.reason,

    required this.visitDate,

    required this.nextVisitDate,

    required this.onTap,

    required this.onEdit,

    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 54,

                height: 54,

                decoration: BoxDecoration(
                  color: AppColors.primaryVeryLight,

                  borderRadius: BorderRadius.circular(16),
                ),

                child: const Icon(
                  Icons.local_hospital_outlined,

                  color: AppColors.primary,

                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      doctorName,

                      style: const TextStyle(
                        fontSize: 16,

                        fontWeight: FontWeight.w700,

                        color: AppColors.darkText,
                      ),
                    ),

                    if (visitDate != null) ...[
                      const SizedBox(height: 5),

                      Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,

                            size: 14,

                            color: AppColors.secondaryText,
                          ),

                          const SizedBox(width: 5),

                          Text(
                            _DoctorVisitsScreenState._formatDate(visitDate!),

                            style: const TextStyle(
                              fontSize: 12,

                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 8),

                      Text(
                        reason,

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 13,

                          color: AppColors.darkText,
                        ),
                      ),
                    ],

                    if (nextVisitDate != null) ...[
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,

                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          color: AppColors.warningLight.withValues(alpha: 0.55),

                          borderRadius: BorderRadius.circular(10),
                        ),

                        child: Text(
                          'Next visit: '
                          '${_DoctorVisitsScreenState._formatDate(nextVisitDate!)}',

                          style: const TextStyle(
                            fontSize: 11,

                            fontWeight: FontWeight.w600,

                            color: Color(0xFF8A6500),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              PopupMenuButton<String>(
                tooltip: 'Visit options',

                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }
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

              const Icon(
                Icons.chevron_right_rounded,

                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================

// EMPTY STATE

// =============================================================

class _EmptyVisitsState extends StatelessWidget {
  final String memberName;

  final VoidCallback onAdd;

  const _EmptyVisitsState({required this.memberName, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),

        child: Column(
          children: [
            Container(
              width: 105,

              height: 105,

              decoration: BoxDecoration(
                color: AppColors.primaryVeryLight,

                borderRadius: BorderRadius.circular(32),
              ),

              child: const Icon(
                Icons.medical_information_outlined,

                size: 50,

                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'No visits recorded',

              style: TextStyle(
                fontSize: 23,

                fontWeight: FontWeight.w800,

                color: AppColors.darkText,
              ),
            ),

            const SizedBox(height: 9),

            Text(
              'Add $memberName\'s doctor visits to keep health information organized.',

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 14,

                height: 1.5,

                color: AppColors.secondaryText,
              ),
            ),

            const SizedBox(height: 26),

            SizedBox(
              height: 52,

              child: ElevatedButton.icon(
                onPressed: onAdd,

                icon: const Icon(Icons.add_rounded),

                label: const Text(
                  'Add First Visit',

                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================

// ERROR STATE

// =============================================================

class _VisitErrorState extends StatelessWidget {
  const _VisitErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.error),

            SizedBox(height: 16),

            Text(
              'Couldn’t load visits',

              style: TextStyle(
                fontSize: 19,

                fontWeight: FontWeight.w700,

                color: AppColors.darkText,
              ),
            ),

            SizedBox(height: 7),

            Text(
              'Please check your connection and try again.',

              textAlign: TextAlign.center,

              style: TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

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
