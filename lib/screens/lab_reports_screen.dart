import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';

class LabReportsScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const LabReportsScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not signed in.');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(widget.memberId)
        .collection('labReports');
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

  CollectionReference<Map<String, dynamic>> get _visits {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not signed in.');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(widget.memberId)
        .collection('visits');
  }

  Future<void> _showForm({
    String? reportId,
    Map<String, dynamic>? existingData,
  }) async {
    final isEditing = reportId != null;

    final nameController = TextEditingController(
      text: existingData?['reportName']?.toString() ?? '',
    );
    final labController = TextEditingController(
      text: existingData?['laboratory']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: existingData?['notes']?.toString() ?? '',
    );

    DateTime reportDate = DateTime.now();
    if (existingData?['reportDate'] is Timestamp) {
      reportDate = (existingData!['reportDate'] as Timestamp).toDate();
    }

    String? doctorId = existingData?['doctorId']?.toString();
    String? doctorName = existingData?['doctorName']?.toString();
    String? visitId = existingData?['visitId']?.toString();
    bool saving = false;

    try {
      final results = await Future.wait([
        _doctors.orderBy('createdAt').get(),
        _visits.orderBy('visitDate', descending: true).get(),
      ]);

      if (!mounted) return;

      final doctors =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final visits =
          results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (doctorId != null &&
          !doctors.docs.any((doc) => doc.id == doctorId)) {
        doctorId = null;
        doctorName = null;
      }

      if (visitId != null &&
          !visits.docs.any((doc) => doc.id == visitId)) {
        visitId = null;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDate() async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: reportDate,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked == null) return;
                setModalState(() => reportDate = picked);
              }

              Future<void> save() async {
                final reportName = nameController.text.trim();
                if (reportName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter the test/report name.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                setModalState(() => saving = true);

                try {
                  final data = <String, dynamic>{
                    'reportName': reportName,
                    'reportDate': Timestamp.fromDate(reportDate),
                    'laboratory': labController.text.trim(),
                    'doctorId': doctorId,
                    'doctorName': doctorName,
                    'visitId': visitId,
                    'notes': notesController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (isEditing) {
                    await _reports.doc(reportId).update(data);
                  } else {
                    data['createdAt'] = FieldValue.serverTimestamp();
                    await _reports.add(data);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Lab report updated.'
                            : 'Lab report saved.',
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
                        'Unable to save lab report. Please try again.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }

              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
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
                        isEditing ? 'Edit Lab Report' : 'Add Lab Report',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Health record for ${widget.memberName}.',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _Label('Test / Report name *'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.science_outlined),
                          hintText: 'Example: Full Blood Count',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Label('Report date'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: saving ? null : pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.event_outlined),
                            suffixIcon:
                                Icon(Icons.calendar_month_outlined),
                          ),
                          child: Text(_date(reportDate)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Label('Laboratory / Hospital'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: labController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          prefixIcon:
                              Icon(Icons.local_hospital_outlined),
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Label('Related doctor (optional)'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: doctorId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon:
                              Icon(Icons.medical_services_outlined),
                          hintText: 'Select doctor',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('No doctor selected'),
                          ),
                          ...doctors.docs.map((doctor) {
                            final data = doctor.data();
                            final name =
                                data['name']?.toString() ?? 'Doctor';
                            return DropdownMenuItem<String>(
                              value: doctor.id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                setModalState(() {
                                  if (value == null || value.isEmpty) {
                                    doctorId = null;
                                    doctorName = null;
                                  } else {
                                    doctorId = value;
                                    doctorName = doctors.docs
                                        .firstWhere(
                                          (doc) => doc.id == value,
                                        )
                                        .data()['name']
                                        ?.toString();
                                  }
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      const _Label('Related doctor visit (optional)'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: visitId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.history_outlined),
                          hintText: 'Select visit',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('No visit selected'),
                          ),
                          ...visits.docs.map((visit) {
                            final data = visit.data();
                            final doctor =
                                data['doctorName']?.toString() ??
                                    'Doctor visit';
                            DateTime? date;
                            if (data['visitDate'] is Timestamp) {
                              date =
                                  (data['visitDate'] as Timestamp)
                                      .toDate();
                            }
                            return DropdownMenuItem<String>(
                              value: visit.id,
                              child: Text(
                                date == null
                                    ? doctor
                                    : '$doctor • ${_date(date)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                setModalState(() {
                                  visitId =
                                      (value == null || value.isEmpty)
                                          ? null
                                          : value;
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      const _Label('Result / Notes'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText:
                              'Add results, important values or notes',
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
                                      : 'Save Lab Report',
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

      // Do not dispose the controllers immediately after the bottom sheet.
      // This follows the modal lifecycle fix used in the other screens.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load lab report form.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _delete(String reportId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete lab report?'),
        content: const Text(
          'Are you sure you want to delete this lab report?',
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
      await _reports.doc(reportId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lab report deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete lab report.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lab Reports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Report'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _reports
            .orderBy('reportDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Couldn’t load lab reports'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data?.docs ?? [];

          if (reports.isEmpty) {
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
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.science_outlined,
                        size: 50,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No lab reports yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add ${widget.memberName}\'s test reports and results.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showForm,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Report'),
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
                '${widget.memberName}\'s Lab Reports',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 14),
              ...reports.map((doc) {
                final data = doc.data();
                final name =
                    data['reportName']?.toString() ?? 'Lab Report';
                final laboratory =
                    data['laboratory']?.toString() ?? '';
                final doctor =
                    data['doctorName']?.toString() ?? '';
                final notes = data['notes']?.toString() ?? '';

                DateTime? reportDate;
                if (data['reportDate'] is Timestamp) {
                  reportDate =
                      (data['reportDate'] as Timestamp).toDate();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        8,
                        16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.science_outlined,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                if (reportDate != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    _date(reportDate),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                          AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                                if (laboratory.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Text(laboratory),
                                ],
                                if (doctor.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Doctor: $doctor',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                          AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Text(
                                    notes,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showForm(
                                  reportId: doc.id,
                                  existingData: data,
                                );
                              } else if (value == 'delete') {
                                _delete(doc.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: AppColors.error,
                                  ),
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
