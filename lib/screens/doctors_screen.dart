import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';

class DoctorsScreen extends StatefulWidget {
  final String memberId;

  final String memberName;

  const DoctorsScreen({
    super.key,

    required this.memberId,

    required this.memberName,
  });

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _doctorsCollection {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not signed in.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(widget.memberId)
        .collection('doctors');
  }

  // ============================================================

  // ADD / EDIT DOCTOR

  // ============================================================

  Future<void> _showDoctorForm({
    String? doctorId,

    Map<String, dynamic>? existingData,
  }) async {
    final isEditing = doctorId != null;

    final nameController = TextEditingController(
      text: existingData?['name']?.toString() ?? '',
    );

    final specialtyController = TextEditingController(
      text: existingData?['specialty']?.toString() ?? '',
    );

    final hospitalController = TextEditingController(
      text: existingData?['hospital']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: existingData?['phone']?.toString() ?? '',
    );

    bool isSaving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveDoctor() async {
              final name = nameController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter the doctor name.'),

                    behavior: SnackBarBehavior.floating,
                  ),
                );

                return;
              }

              setModalState(() {
                isSaving = true;
              });

              try {
                final data = <String, dynamic>{
                  'name': name,

                  'specialty': specialtyController.text.trim(),

                  'hospital': hospitalController.text.trim(),

                  'phone': phoneController.text.trim(),

                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEditing) {
                  await _doctorsCollection.doc(doctorId).update(data);
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();

                  await _doctorsCollection.add(data);
                }

                if (!context.mounted) return;

                Navigator.pop(context, true);
              } catch (e) {
                if (!context.mounted) return;

                setModalState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to save doctor. Please try again.'),

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
                            color: AppColors.successLight,

                            borderRadius: BorderRadius.circular(15),
                          ),

                          child: Icon(
                            isEditing
                                ? Icons.edit_outlined
                                : Icons.medical_services_outlined,

                            color: AppColors.success,
                          ),
                        ),

                        const SizedBox(width: 13),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                isEditing ? 'Edit Doctor' : 'Add Doctor',

                                style: const TextStyle(
                                  fontSize: 21,

                                  fontWeight: FontWeight.w700,

                                  color: AppColors.darkText,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                'Add a doctor for ${widget.memberName}.',

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

                    const _FieldLabel('Doctor name'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: nameController,

                      textCapitalization: TextCapitalization.words,

                      textInputAction: TextInputAction.next,

                      decoration: const InputDecoration(
                        hintText: 'Example: Dr. Silva',

                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const _FieldLabel('Specialty'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: specialtyController,

                      textCapitalization: TextCapitalization.words,

                      textInputAction: TextInputAction.next,

                      decoration: const InputDecoration(
                        hintText: 'Example: Cardiologist',

                        prefixIcon: Icon(Icons.favorite_border_rounded),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const _FieldLabel('Hospital / Clinic'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: hospitalController,

                      textCapitalization: TextCapitalization.words,

                      textInputAction: TextInputAction.next,

                      decoration: const InputDecoration(
                        hintText: 'Enter hospital or clinic',

                        prefixIcon: Icon(Icons.local_hospital_outlined),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const _FieldLabel('Phone number'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: phoneController,

                      keyboardType: TextInputType.phone,

                      textInputAction: TextInputAction.done,

                      onSubmitted: (_) {
                        if (!isSaving) {
                          saveDoctor();
                        }
                      },

                      decoration: const InputDecoration(
                        hintText: 'Enter phone number',

                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,

                      height: 54,

                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : saveDoctor,

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
                                isEditing ? 'Save Changes' : 'Add Doctor',

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

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Doctor updated successfully.'
                : 'Doctor added successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================

  // DELETE

  // ============================================================

  Future<void> _deleteDoctor(String doctorId, String doctorName) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove doctor?'),

          content: Text('Are you sure you want to remove $doctorName?'),

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
                'Remove',

                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _doctorsCollection.doc(doctorId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$doctorName removed.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to remove doctor.'),

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================

  // UI

  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctors')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showDoctorForm();
        },

        icon: const Icon(Icons.add_rounded),

        label: const Text(
          'Add Doctor',

          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _doctorsCollection
            .orderBy('createdAt', descending: false)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _DoctorErrorState();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final doctors = snapshot.data?.docs ?? [];

          if (doctors.isEmpty) {
            return _EmptyDoctorsState(
              memberName: widget.memberName,

              onAdd: () {
                _showDoctorForm();
              },
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),

            children: [
              // MEMBER SUMMARY

              Container(
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.55),

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
                        Icons.medical_services_outlined,

                        color: AppColors.success,

                        size: 27,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            '${widget.memberName}\'s Care Team',

                            style: const TextStyle(
                              fontSize: 17,

                              fontWeight: FontWeight.w700,

                              color: AppColors.darkText,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '${doctors.length} '
                            '${doctors.length == 1 ? 'doctor' : 'doctors'} saved',

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
                'Saved Doctors',

                style: TextStyle(
                  fontSize: 19,

                  fontWeight: FontWeight.w700,

                  color: AppColors.darkText,
                ),
              ),

              const SizedBox(height: 14),

              ...doctors.map((document) {
                final data = document.data();

                final name = data['name']?.toString() ?? 'Doctor';

                final specialty = data['specialty']?.toString() ?? '';

                final hospital = data['hospital']?.toString() ?? '';

                final phone = data['phone']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),

                  child: _DoctorCard(
                    name: name,

                    specialty: specialty,

                    hospital: hospital,

                    phone: phone,

                    onEdit: () {
                      _showDoctorForm(
                        doctorId: document.id,

                        existingData: data,
                      );
                    },

                    onDelete: () {
                      _deleteDoctor(document.id, name);
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

// DOCTOR CARD

// =============================================================

class _DoctorCard extends StatelessWidget {
  final String name;

  final String specialty;

  final String hospital;

  final String phone;

  final VoidCallback onEdit;

  final VoidCallback onDelete;

  const _DoctorCard({
    required this.name,

    required this.specialty,

    required this.hospital,

    required this.phone,

    required this.onEdit,

    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Container(
              width: 55,

              height: 55,

              decoration: BoxDecoration(
                color: AppColors.successLight,

                borderRadius: BorderRadius.circular(17),
              ),

              child: const Icon(
                Icons.medical_services_outlined,

                color: AppColors.success,

                size: 27,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    name,

                    style: const TextStyle(
                      fontSize: 16,

                      fontWeight: FontWeight.w700,

                      color: AppColors.darkText,
                    ),
                  ),

                  if (specialty.isNotEmpty) ...[
                    const SizedBox(height: 4),

                    Text(
                      specialty,

                      style: const TextStyle(
                        fontSize: 13,

                        fontWeight: FontWeight.w600,

                        color: AppColors.success,
                      ),
                    ),
                  ],

                  if (hospital.isNotEmpty) ...[
                    const SizedBox(height: 7),

                    Row(
                      children: [
                        const Icon(
                          Icons.local_hospital_outlined,

                          size: 14,

                          color: AppColors.secondaryText,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            hospital,

                            style: const TextStyle(
                              fontSize: 12,

                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,

                          size: 14,

                          color: AppColors.secondaryText,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            phone,

                            style: const TextStyle(
                              fontSize: 12,

                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            PopupMenuButton<String>(
              tooltip: 'Doctor options',

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
                          'Remove',

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

// EMPTY STATE

// =============================================================

class _EmptyDoctorsState extends StatelessWidget {
  final String memberName;

  final VoidCallback onAdd;

  const _EmptyDoctorsState({required this.memberName, required this.onAdd});

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
                color: AppColors.successLight,

                borderRadius: BorderRadius.circular(32),
              ),

              child: const Icon(
                Icons.medical_services_outlined,

                size: 50,

                color: AppColors.success,
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'No doctors yet',

              style: TextStyle(
                fontSize: 23,

                fontWeight: FontWeight.w800,

                color: AppColors.darkText,
              ),
            ),

            const SizedBox(height: 9),

            Text(
              'Add doctors who provide care for $memberName.',

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
                  'Add First Doctor',

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

class _DoctorErrorState extends StatelessWidget {
  const _DoctorErrorState();

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
              'Couldn’t load doctors',

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
