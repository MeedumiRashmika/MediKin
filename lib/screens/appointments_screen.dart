import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';

import '../services/notification_service.dart';

class AppointmentsScreen extends StatefulWidget {
  final String memberId;

  final String memberName;

  const AppointmentsScreen({
    super.key,

    required this.memberId,

    required this.memberName,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _auth = FirebaseAuth.instance;

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _appointments {
    final user = _auth.currentUser;

    if (user == null) throw Exception('User is not signed in.');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(widget.memberId)
        .collection('appointments');
  }

  CollectionReference<Map<String, dynamic>> get _doctors {
    final user = _auth.currentUser;

    if (user == null) throw Exception('User is not signed in.');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(widget.memberId)
        .collection('doctors');
  }

  int _appointmentNotificationBaseId(String appointmentId) {
    int hash = 0;

    for (final codeUnit in appointmentId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x3fffffff;
    }

    return 700000000 + (hash % 100000000);
  }

  Future<void> _showForm({
    String? appointmentId,

    Map<String, dynamic>? existingData,
  }) async {
    final isEditing = appointmentId != null;

    final reasonController = TextEditingController(
      text: existingData?['reason']?.toString() ?? '',
    );

    final notesController = TextEditingController(
      text: existingData?['notes']?.toString() ?? '',
    );

    DateTime appointmentDateTime = DateTime.now().add(const Duration(days: 1));

    if (existingData?['appointmentDateTime'] is Timestamp) {
      appointmentDateTime = (existingData!['appointmentDateTime'] as Timestamp)
          .toDate();
    }

    String? doctorId = existingData?['doctorId']?.toString();

    String? doctorName = existingData?['doctorName']?.toString();

    bool saving = false;

    try {
      final snapshot = await _doctors.orderBy('createdAt').get();

      if (!mounted) return;

      final doctors = snapshot.docs;

      if (doctors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please add a doctor before creating an appointment.',
            ),

            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      if (doctorId != null && !doctors.any((doctor) => doctor.id == doctorId)) {
        doctorId = null;

        doctorName = null;
      }

      await showModalBottomSheet(
        context: context,

        isScrollControlled: true,

        backgroundColor: Colors.transparent,

        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDate() async {
                final now = DateTime.now();

                final today = DateTime(now.year, now.month, now.day);

                final initial = appointmentDateTime.isBefore(today)
                    ? today
                    : appointmentDateTime;

                final picked = await showDatePicker(
                  context: context,

                  initialDate: initial,

                  firstDate: today,

                  lastDate: DateTime(now.year + 10),
                );

                if (picked == null) return;

                setModalState(() {
                  appointmentDateTime = DateTime(
                    picked.year,

                    picked.month,

                    picked.day,

                    appointmentDateTime.hour,

                    appointmentDateTime.minute,
                  );
                });
              }

              Future<void> pickTime() async {
                final picked = await showTimePicker(
                  context: context,

                  initialTime: TimeOfDay.fromDateTime(appointmentDateTime),
                );

                if (picked == null) return;

                setModalState(() {
                  appointmentDateTime = DateTime(
                    appointmentDateTime.year,

                    appointmentDateTime.month,

                    appointmentDateTime.day,

                    picked.hour,

                    picked.minute,
                  );
                });
              }

              Future<void> save() async {
                if (doctorId == null || doctorName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a doctor.'),

                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  return;
                }

                if (!appointmentDateTime.isAfter(DateTime.now())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please select a future appointment date and time.',
                      ),

                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  return;
                }

                setModalState(() => saving = true);

                try {
                  final appointmentReference = isEditing
                      ? _appointments.doc(appointmentId)
                      : _appointments.doc();

                  if (isEditing) {
                    final oldSnapshot = await appointmentReference.get();

                    final oldIdsRaw = oldSnapshot
                        .data()?['appointmentReminderIds'];

                    if (oldIdsRaw is List) {
                      final oldIds = oldIdsRaw
                          .whereType<num>()
                          .map((id) => id.toInt())
                          .toList();

                      await NotificationService.instance
                          .cancelAppointmentReminders(oldIds);
                    }
                  }

                  final reminderIds = await NotificationService.instance
                      .scheduleAppointmentReminders(
                        memberName: widget.memberName,

                        doctorName: doctorName!,

                        appointmentDateTime: appointmentDateTime,

                        baseNotificationId: _appointmentNotificationBaseId(
                          appointmentReference.id,
                        ),
                      );

                  final data = <String, dynamic>{
                    'doctorId': doctorId,

                    'doctorName': doctorName,

                    'appointmentDateTime': Timestamp.fromDate(
                      appointmentDateTime,
                    ),

                    'reason': reasonController.text.trim(),

                    'notes': notesController.text.trim(),

                    'appointmentReminderIds': reminderIds,

                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (isEditing) {
                    await appointmentReference.update(data);
                  } else {
                    data['createdAt'] = FieldValue.serverTimestamp();

                    await appointmentReference.set(data);
                  }

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  if (!mounted) return;

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Appointment updated.'
                            : 'Appointment saved.',
                      ),

                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (_) {
                  if (!context.mounted) return;

                  setModalState(() => saving = false);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to save appointment. Please try again.',
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

                      Text(
                        isEditing ? 'Edit Appointment' : 'Add Appointment',

                        style: const TextStyle(
                          fontSize: 21,

                          fontWeight: FontWeight.w700,

                          color: AppColors.darkText,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Schedule care for ${widget.memberName}.',

                        style: const TextStyle(color: AppColors.secondaryText),
                      ),

                      const SizedBox(height: 24),

                      const _Label('Doctor'),

                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        initialValue: doctorId,

                        isExpanded: true,

                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.medical_services_outlined),

                          hintText: 'Select doctor',
                        ),

                        items: doctors.map((doctor) {
                          final data = doctor.data();

                          final name = data['name']?.toString() ?? 'Doctor';

                          final specialty = data['specialty']?.toString() ?? '';

                          return DropdownMenuItem<String>(
                            value: doctor.id,

                            child: Text(
                              specialty.isEmpty ? name : '$name • $specialty',

                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),

                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;

                                final selected = doctors.firstWhere(
                                  (doctor) => doctor.id == value,
                                );

                                setModalState(() {
                                  doctorId = value;

                                  doctorName =
                                      selected.data()['name']?.toString() ??
                                      'Doctor';
                                });
                              },
                      ),

                      const SizedBox(height: 18),

                      const _Label('Appointment date'),

                      const SizedBox(height: 8),

                      InkWell(
                        onTap: saving ? null : pickDate,

                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.event_outlined),

                            suffixIcon: Icon(Icons.calendar_month_outlined),
                          ),

                          child: Text(_date(appointmentDateTime)),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _Label('Appointment time'),

                      const SizedBox(height: 8),

                      InkWell(
                        onTap: saving ? null : pickTime,

                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.schedule_outlined),

                            suffixIcon: Icon(Icons.access_time_rounded),
                          ),

                          child: Text(_time(context, appointmentDateTime)),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _Label('Reason'),

                      const SizedBox(height: 8),

                      TextField(
                        controller: reasonController,

                        textCapitalization: TextCapitalization.sentences,

                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.description_outlined),

                          hintText: 'Example: Follow-up consultation',
                        ),
                      ),

                      const SizedBox(height: 18),

                      const _Label('Notes'),

                      const SizedBox(height: 8),

                      TextField(
                        controller: notesController,

                        textCapitalization: TextCapitalization.sentences,

                        minLines: 3,

                        maxLines: 5,

                        decoration: const InputDecoration(
                          hintText: 'Preparation notes or other details',
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,

                        height: 54,

                        child: ElevatedButton.icon(
                          onPressed: saving ? null : save,

                          icon: saving
                              ? const SizedBox.shrink()
                              : const Icon(Icons.check_rounded),

                          label: saving
                              ? const SizedBox(
                                  width: 23,

                                  height: 23,

                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,

                                    color: AppColors.white,
                                  ),
                                )
                              : Text(
                                  isEditing
                                      ? 'Save Changes'
                                      : 'Save Appointment',

                                  style: const TextStyle(
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

      // Intentionally no immediate controller.dispose() here.

      // This preserves the modal lifecycle fix used elsewhere.
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load doctors.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete appointment?'),

        content: const Text(
          'Are you sure you want to delete this appointment?',
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
      ),
    );

    if (confirmed != true) return;

    try {
      final appointmentReference = _appointments.doc(id);

      final snapshot = await appointmentReference.get();

      final reminderIdsRaw = snapshot.data()?['appointmentReminderIds'];

      if (reminderIdsRaw is List) {
        final reminderIds = reminderIdsRaw
            .whereType<num>()
            .map((value) => value.toInt())
            .toList();

        await NotificationService.instance.cancelAppointmentReminders(
          reminderIds,
        );
      }

      await appointmentReference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment deleted.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete appointment.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static String _date(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');

    final m = date.month.toString().padLeft(2, '0');

    return '$d/$m/${date.year}';
  }

  static String _time(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showForm,

        icon: const Icon(Icons.add_rounded),

        label: const Text('Add Appointment'),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _appointments.orderBy('appointmentDateTime').snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Couldn’t load appointments'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
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
                        Icons.calendar_month_outlined,

                        size: 50,

                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'No appointments scheduled',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 22,

                        fontWeight: FontWeight.w800,

                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Add ${widget.memberName}\'s next appointment.',

                      textAlign: TextAlign.center,

                      style: const TextStyle(color: AppColors.secondaryText),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _showForm,

                      icon: const Icon(Icons.add_rounded),

                      label: const Text('Add First Appointment'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),

            children: [
              Text(
                '${widget.memberName}\'s Appointments',

                style: const TextStyle(
                  fontSize: 19,

                  fontWeight: FontWeight.w700,

                  color: AppColors.darkText,
                ),
              ),

              const SizedBox(height: 14),

              ...items.map((doc) {
                final data = doc.data();

                final doctor = data['doctorName']?.toString() ?? 'Doctor';

                final reason = data['reason']?.toString() ?? '';

                final notes = data['notes']?.toString() ?? '';

                DateTime? dateTime;

                if (data['appointmentDateTime'] is Timestamp) {
                  dateTime = (data['appointmentDateTime'] as Timestamp)
                      .toDate();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),

                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Container(
                            width: 52,

                            height: 52,

                            decoration: BoxDecoration(
                              color: AppColors.primaryVeryLight,

                              borderRadius: BorderRadius.circular(16),
                            ),

                            child: const Icon(
                              Icons.event_available_outlined,

                              color: AppColors.primary,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  doctor,

                                  style: const TextStyle(
                                    fontSize: 16,

                                    fontWeight: FontWeight.w700,

                                    color: AppColors.darkText,
                                  ),
                                ),

                                if (dateTime != null) ...[
                                  const SizedBox(height: 5),

                                  Text(
                                    '${_date(dateTime)} • ${_time(context, dateTime)}',

                                    style: const TextStyle(
                                      fontSize: 12,

                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],

                                if (reason.isNotEmpty) ...[
                                  const SizedBox(height: 8),

                                  Text(
                                    reason,

                                    maxLines: 2,

                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],

                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 4),

                                  Text(
                                    notes,

                                    maxLines: 2,

                                    overflow: TextOverflow.ellipsis,

                                    style: const TextStyle(
                                      fontSize: 12,

                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showForm(
                                  appointmentId: doc.id,

                                  existingData: data,
                                );
                              } else if (value == 'delete') {
                                _delete(doc.id);
                              }
                            },

                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),

                              PopupMenuItem(
                                value: 'delete',

                                child: Text(
                                  'Delete',

                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

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
