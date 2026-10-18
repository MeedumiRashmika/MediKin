import 'package:flutter/material.dart';



import 'package:firebase_auth/firebase_auth.dart';



import 'package:cloud_firestore/cloud_firestore.dart';



import '../theme/app_colors.dart';

import '../services/notification_service.dart';



import 'member_profile_screen.dart';



class FamilyMembersScreen extends StatefulWidget {

  const FamilyMembersScreen({super.key});



  @override

  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();

}



class _FamilyMembersScreenState extends State<FamilyMembersScreen> {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  final FirebaseAuth _auth = FirebaseAuth.instance;



  // ============================================================



  // FIRESTORE COLLECTION



  // users/{uid}/familyMembers/{memberId}



  // ============================================================



  CollectionReference<Map<String, dynamic>> get _membersCollection {

    final user = _auth.currentUser;



    if (user == null) {

      throw Exception('User is not signed in.');

    }



    return _firestore

        .collection('users')

        .doc(user.uid)

        .collection('familyMembers');

  }



  // ============================================================



  // ADD / EDIT MEMBER



  // ============================================================



  Future<void> _showMemberForm({

    String? documentId,



    Map<String, dynamic>? existingData,

  }) async {

    final bool isEditing = documentId != null;



    final nameController = TextEditingController(

      text: existingData?['name']?.toString() ?? '',

    );



    final relationshipController = TextEditingController(

      text: existingData?['relationship']?.toString() ?? '',

    );



    DateTime? selectedDate;



    if (existingData?['dateOfBirth'] is Timestamp) {

      selectedDate = (existingData!['dateOfBirth'] as Timestamp).toDate();

    }



    String selectedGender =

        existingData?['gender']?.toString() ?? 'Prefer not to say';



    bool isSaving = false;



    final saved = await showModalBottomSheet<bool>(

      context: context,



      isScrollControlled: true,



      backgroundColor: Colors.transparent,



      builder: (sheetContext) {

        return StatefulBuilder(

          builder: (context, setModalState) {

            // ==================================================



            // SELECT DATE



            // ==================================================



            Future<void> selectDate() async {

              final now = DateTime.now();



              final pickedDate = await showDatePicker(

                context: context,



                initialDate:

                    selectedDate ?? DateTime(now.year - 20, now.month, now.day),



                firstDate: DateTime(1900),



                lastDate: now,

              );



              if (pickedDate != null) {

                setModalState(() {

                  selectedDate = pickedDate;

                });

              }

            }



            // ==================================================



            // SAVE MEMBER



            // ==================================================



            Future<void> saveMember() async {

              final name = nameController.text.trim();



              final relationship = relationshipController.text.trim();



              if (name.isEmpty) {

                ScaffoldMessenger.of(context).showSnackBar(

                  const SnackBar(

                    content: Text('Please enter the member name.'),



                    behavior: SnackBarBehavior.floating,

                  ),

                );



                return;

              }



              if (relationship.isEmpty) {

                ScaffoldMessenger.of(context).showSnackBar(

                  const SnackBar(

                    content: Text('Please enter the relationship.'),



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



                  'relationship': relationship,



                  'gender': selectedGender,



                  'dateOfBirth': selectedDate == null

                      ? null

                      : Timestamp.fromDate(selectedDate!),



                  'updatedAt': FieldValue.serverTimestamp(),

                };



                // ----------------------------------------------



                // EDIT EXISTING MEMBER



                // ----------------------------------------------



                if (isEditing) {

                  await _membersCollection.doc(documentId).update(data);

                }

                // ----------------------------------------------

                // ADD NEW MEMBER

                // ----------------------------------------------

                else {

                  data['createdAt'] = FieldValue.serverTimestamp();



                  await _membersCollection.add(data);

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

                    content: Text(

                      'Unable to save the family member. Please try again.',

                    ),



                    behavior: SnackBarBehavior.floating,

                  ),

                );

              }

            }



            // ==================================================



            // BOTTOM SHEET UI



            // ==================================================



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

                    // ------------------------------------------



                    // HANDLE



                    // ------------------------------------------

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



                    // ------------------------------------------



                    // TITLE



                    // ------------------------------------------

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

                                ? Icons.edit_outlined

                                : Icons.person_add_alt_1_rounded,



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

                                    ? 'Edit Family Member'

                                    : 'Add Family Member',



                                style: const TextStyle(

                                  fontSize: 21,



                                  fontWeight: FontWeight.w700,



                                  color: AppColors.darkText,

                                ),

                              ),



                              const SizedBox(height: 3),



                              const Text(

                                'Add basic information for this profile.',



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



                    const SizedBox(height: 28),



                    // ------------------------------------------



                    // NAME



                    // ------------------------------------------

                    const _FieldLabel(text: 'Full name'),



                    const SizedBox(height: 8),



                    TextField(

                      controller: nameController,



                      textCapitalization: TextCapitalization.words,



                      textInputAction: TextInputAction.next,



                      decoration: const InputDecoration(

                        hintText: 'Enter full name',



                        prefixIcon: Icon(Icons.person_outline_rounded),

                      ),

                    ),



                    const SizedBox(height: 18),



                    // ------------------------------------------



                    // RELATIONSHIP



                    // ------------------------------------------

                    const _FieldLabel(text: 'Relationship'),



                    const SizedBox(height: 8),



                    TextField(

                      controller: relationshipController,



                      textCapitalization: TextCapitalization.words,



                      textInputAction: TextInputAction.next,



                      decoration: const InputDecoration(

                        hintText: 'Example: Me, Mother, Father',



                        prefixIcon: Icon(Icons.family_restroom_rounded),

                      ),

                    ),



                    const SizedBox(height: 18),



                    // ------------------------------------------



                    // DATE OF BIRTH



                    // ------------------------------------------

                    const _FieldLabel(text: 'Date of birth'),



                    const SizedBox(height: 8),



                    InkWell(

                      borderRadius: BorderRadius.circular(14),



                      onTap: isSaving ? null : selectDate,



                      child: InputDecorator(

                        decoration: const InputDecoration(

                          prefixIcon: Icon(Icons.cake_outlined),



                          suffixIcon: Icon(Icons.calendar_month_outlined),

                        ),



                        child: Text(

                          selectedDate == null

                              ? 'Select date of birth'

                              : _formatDate(selectedDate!),



                          style: TextStyle(

                            fontSize: 14,



                            color: selectedDate == null

                                ? AppColors.secondaryText

                                : AppColors.darkText,

                          ),

                        ),

                      ),

                    ),



                    const SizedBox(height: 18),



                    // ------------------------------------------



                    // GENDER



                    // ------------------------------------------

                    const _FieldLabel(text: 'Gender'),



                    const SizedBox(height: 8),



                    DropdownButtonFormField<String>(

                      initialValue: selectedGender,



                      decoration: const InputDecoration(

                        prefixIcon: Icon(Icons.person_search_outlined),

                      ),



                      items: const [

                        DropdownMenuItem(

                          value: 'Female',



                          child: Text('Female'),

                        ),



                        DropdownMenuItem(value: 'Male', child: Text('Male')),



                        DropdownMenuItem(value: 'Other', child: Text('Other')),



                        DropdownMenuItem(

                          value: 'Prefer not to say',



                          child: Text('Prefer not to say'),

                        ),

                      ],



                      onChanged: isSaving

                          ? null

                          : (value) {

                              if (value == null) return;



                              setModalState(() {

                                selectedGender = value;

                              });

                            },

                    ),



                    const SizedBox(height: 28),



                    // ------------------------------------------



                    // SAVE BUTTON



                    // ------------------------------------------

                    SizedBox(

                      width: double.infinity,



                      height: 54,



                      child: ElevatedButton.icon(

                        onPressed: isSaving ? null : saveMember,



                        icon: isSaving

                            ? const SizedBox.shrink()

                            : Icon(

                                isEditing

                                    ? Icons.check_rounded

                                    : Icons.person_add_alt_1_rounded,

                              ),



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

                                isEditing

                                    ? 'Save Changes'

                                    : 'Add Family Member',



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

                ? 'Family member updated successfully.'

                : 'Family member added successfully.',

          ),



          behavior: SnackBarBehavior.floating,

        ),

      );

    }

  }



  // ============================================================



  // DELETE MEMBER



  // ============================================================



  Future<void> _deleteMember({

    required String documentId,



    required String name,

  }) async {

    final shouldDelete = await showDialog<bool>(

      context: context,



      builder: (dialogContext) {

        return AlertDialog(

          title: const Text('Remove family member?'),



          content: Text(

            'Are you sure you want to remove $name from MediKIN?',

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

                'Remove',



                style: TextStyle(color: AppColors.error),

              ),

            ),

          ],

        );

      },

    );



    if (shouldDelete != true) return;



    try {

      final memberReference = _membersCollection.doc(documentId);

      // Delete visits and their nested medicines first.
      final visitsSnapshot = await memberReference.collection('visits').get();

      for (final visitDoc in visitsSnapshot.docs) {
        final visitData = visitDoc.data();

        final rawVisitReminderIds = visitData['visitReminderIds'];
        if (rawVisitReminderIds is List) {
          final visitReminderIds = rawVisitReminderIds
              .whereType<num>()
              .map((id) => id.toInt())
              .toList();

          if (visitReminderIds.isNotEmpty) {
            await NotificationService.instance.cancelVisitReminders(
              visitReminderIds,
            );
          }
        }

        final medicinesSnapshot =
            await visitDoc.reference.collection('medicines').get();

        for (final medicineDoc in medicinesSnapshot.docs) {
          final medicineData = medicineDoc.data();
          final rawNotificationIds = medicineData['notificationIds'];

          if (rawNotificationIds is List) {
            final notificationIds = rawNotificationIds
                .whereType<num>()
                .map((id) => id.toInt())
                .toList();

            for (final notificationId in notificationIds) {
              await NotificationService.instance.cancelNotification(
                notificationId,
              );
            }
          }
        }

        await _deleteDocumentsInChunks(medicinesSnapshot.docs);
      }

      await _deleteDocumentsInChunks(visitsSnapshot.docs);

      // Delete appointments after cancelling their reminders.
      final appointmentsSnapshot =
          await memberReference.collection('appointments').get();

      for (final appointmentDoc in appointmentsSnapshot.docs) {
        final appointmentData = appointmentDoc.data();
        final rawReminderIds = appointmentData['appointmentReminderIds'];

        if (rawReminderIds is List) {
          final reminderIds = rawReminderIds
              .whereType<num>()
              .map((id) => id.toInt())
              .toList();

          if (reminderIds.isNotEmpty) {
            await NotificationService.instance.cancelAppointmentReminders(
              reminderIds,
            );
          }
        }
      }

      await _deleteDocumentsInChunks(appointmentsSnapshot.docs);

      // Delete remaining direct subcollections.
      final doctorsSnapshot = await memberReference.collection('doctors').get();
      await _deleteDocumentsInChunks(doctorsSnapshot.docs);

      final labReportsSnapshot =
          await memberReference.collection('labReports').get();
      await _deleteDocumentsInChunks(labReportsSnapshot.docs);

      // Delete the family member only after all known child data is removed.
      await memberReference.delete();



      if (!mounted) return;



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text('$name removed.'),



          behavior: SnackBarBehavior.floating,

        ),

      );

    } catch (e) {

      if (!mounted) return;



      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Unable to remove the family member.'),



          behavior: SnackBarBehavior.floating,

        ),

      );

    }

  }

  // ============================================================
  // SAFE BATCH DELETE HELPER
  // ============================================================

  Future<void> _deleteDocumentsInChunks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    const batchLimit = 450;

    for (var start = 0; start < documents.length; start += batchLimit) {
      final batch = _firestore.batch();
      final end = (start + batchLimit < documents.length)
          ? start + batchLimit
          : documents.length;

      for (var i = start; i < end; i++) {
        batch.delete(documents[i].reference);
      }

      await batch.commit();
    }
  }





  // ============================================================



  // DATE FORMAT



  // ============================================================



  static String _formatDate(DateTime date) {

    final day = date.day.toString().padLeft(2, '0');



    final month = date.month.toString().padLeft(2, '0');



    return '$day/$month/${date.year}';

  }



  // ============================================================



  // MAIN SCREEN



  // ============================================================



  @override

  Widget build(BuildContext context) {

    final user = _auth.currentUser;



    if (user == null) {

      return const Scaffold(body: Center(child: Text('Please sign in again.')));

    }



    return Scaffold(

      appBar: AppBar(

        title: const Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text('Family Members'),

            SizedBox(height: 2),

            Text(

              'Manage your family health profiles',

              style: TextStyle(

                fontSize: 11,

                fontWeight: FontWeight.w500,

                color: AppColors.secondaryText,

              ),

            ),

          ],

        ),

      ),



      // ========================================================



      // ADD MEMBER BUTTON



      // ========================================================

      floatingActionButton: FloatingActionButton.extended(

        onPressed: () {

          _showMemberForm();

        },



        icon: const Icon(Icons.person_add_alt_1_rounded),



        label: const Text(

          'Add Member',



          style: TextStyle(fontWeight: FontWeight.w600),

        ),

      ),



      // ========================================================



      // FIRESTORE DATA



      // ========================================================

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(

        stream: _membersCollection

            .orderBy('createdAt', descending: false)

            .snapshots(),



        builder: (context, snapshot) {

          // --------------------------------------------



          // ERROR



          // --------------------------------------------



          if (snapshot.hasError) {

            return _ErrorState(

              onRetry: () {

                setState(() {});

              },

            );

          }



          // --------------------------------------------



          // LOADING



          // --------------------------------------------



          if (snapshot.connectionState == ConnectionState.waiting) {

            return const Center(child: CircularProgressIndicator());

          }



          final members = snapshot.data?.docs ?? [];



          // --------------------------------------------



          // EMPTY



          // --------------------------------------------



          if (members.isEmpty) {

            return _EmptyFamilyState(

              onAddMember: () {

                _showMemberForm();

              },

            );

          }



          // --------------------------------------------



          // FAMILY MEMBER LIST



          // --------------------------------------------



          return ListView(

            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),



            children: [

              // ==========================================



              // FAMILY SUMMARY



              // ==========================================

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

                        Icons.family_restroom_rounded,



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

                            '${members.length} '

                            '${members.length == 1 ? 'family member' : 'family members'}',



                            style: const TextStyle(

                              fontSize: 17,



                              fontWeight: FontWeight.w700,



                              color: AppColors.darkText,

                            ),

                          ),



                          const SizedBox(height: 4),



                          const Text(

                            'Choose a member to manage their health records.',



                            style: TextStyle(

                              fontSize: 12,



                              height: 1.4,



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



              // ==========================================



              // TITLE



              // ==========================================

              const Text(

                'Your Family',



                style: TextStyle(

                  fontSize: 19,



                  fontWeight: FontWeight.w700,



                  color: AppColors.darkText,

                ),

              ),



              const SizedBox(height: 14),



              // ==========================================



              // MEMBER CARDS



              // ==========================================

              ...members.map((document) {

                final data = document.data();



                final name = data['name']?.toString() ?? 'Family Member';



                final relationship = data['relationship']?.toString() ?? '';



                final gender = data['gender']?.toString() ?? '';



                DateTime? dateOfBirth;



                if (data['dateOfBirth'] is Timestamp) {

                  dateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();

                }



                return Padding(

                  padding: const EdgeInsets.only(bottom: 12),



                  child: _FamilyMemberCard(

                    name: name,



                    relationship: relationship,



                    gender: gender,



                    dateOfBirth: dateOfBirth,



                    // ====================================



                    // OPEN MEMBER PROFILE



                    // IMPORTANT:



                    // Pass Firestore member ID



                    // ====================================

                    onTap: () {

                      Navigator.push(

                        context,



                        MaterialPageRoute(

                          builder: (context) => MemberProfileScreen(

                            memberId: document.id,



                            memberName: name,

                          ),

                        ),

                      );

                    },



                    // ====================================



                    // EDIT



                    // ====================================

                    onEdit: () {

                      _showMemberForm(

                        documentId: document.id,



                        existingData: data,

                      );

                    },



                    // ====================================



                    // DELETE



                    // ====================================

                    onDelete: () {

                      _deleteMember(documentId: document.id, name: name);

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



// FAMILY MEMBER CARD



// =============================================================



class _FamilyMemberCard extends StatelessWidget {

  final String name;



  final String relationship;



  final String gender;



  final DateTime? dateOfBirth;



  final VoidCallback onTap;



  final VoidCallback onEdit;



  final VoidCallback onDelete;



  const _FamilyMemberCard({

    required this.name,



    required this.relationship,



    required this.gender,



    required this.dateOfBirth,



    required this.onTap,



    required this.onEdit,



    required this.onDelete,

  });



  @override

  Widget build(BuildContext context) {

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';



    return Card(

      child: InkWell(

        onTap: onTap,



        borderRadius: BorderRadius.circular(22),



        child: Padding(

          padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),



          child: Row(

            children: [

              // ==========================================



              // AVATAR



              // ==========================================

              Container(

                width: 58,



                height: 58,



                alignment: Alignment.center,



                decoration: BoxDecoration(

                  color: AppColors.primaryVeryLight,



                  borderRadius: BorderRadius.circular(17),

                ),



                child: Text(

                  initial,



                  style: const TextStyle(

                    fontSize: 22,



                    fontWeight: FontWeight.w800,



                    color: AppColors.primary,

                  ),

                ),

              ),



              const SizedBox(width: 14),



              // ==========================================



              // INFORMATION



              // ==========================================

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,



                  children: [

                    Text(

                      name,



                      maxLines: 1,



                      overflow: TextOverflow.ellipsis,



                      style: const TextStyle(

                        fontSize: 16,



                        fontWeight: FontWeight.w700,



                        color: AppColors.darkText,

                      ),

                    ),



                    const SizedBox(height: 5),



                    if (relationship.isNotEmpty)

                      Text(

                        relationship,



                        style: const TextStyle(

                          fontSize: 13,



                          fontWeight: FontWeight.w600,



                          color: AppColors.primary,

                        ),

                      ),



                    if (dateOfBirth != null) ...[

                      const SizedBox(height: 6),



                      Row(

                        children: [

                          const Icon(

                            Icons.cake_outlined,



                            size: 14,



                            color: AppColors.secondaryText,

                          ),



                          const SizedBox(width: 5),



                          Flexible(

                            child: Text(

                              _formatMemberDate(dateOfBirth!),



                              style: const TextStyle(

                                fontSize: 11,



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



              // ==========================================



              // OPTIONS



              // ==========================================

              PopupMenuButton<String>(

                tooltip: 'Member options',



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



              const Icon(

                Icons.chevron_right_rounded,



                size: 22,



                color: AppColors.secondaryText,

              ),

            ],

          ),

        ),

      ),

    );

  }



  String _formatMemberDate(DateTime date) {

    final day = date.day.toString().padLeft(2, '0');



    final month = date.month.toString().padLeft(2, '0');



    return '$day/$month/${date.year}';

  }

}



// =============================================================



// EMPTY FAMILY STATE



// =============================================================



class _EmptyFamilyState extends StatelessWidget {

  final VoidCallback onAddMember;



  const _EmptyFamilyState({required this.onAddMember});



  @override

  Widget build(BuildContext context) {

    return Center(

      child: SingleChildScrollView(

        padding: const EdgeInsets.all(28),



        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,



          children: [

            Container(

              width: 105,



              height: 105,



              decoration: BoxDecoration(

                color: AppColors.primaryVeryLight,



                borderRadius: BorderRadius.circular(32),

              ),



              child: const Icon(

                Icons.family_restroom_rounded,



                size: 52,



                color: AppColors.primary,

              ),

            ),



            const SizedBox(height: 25),



            const Text(

              'Start with your family',



              textAlign: TextAlign.center,



              style: TextStyle(

                fontSize: 23,



                fontWeight: FontWeight.w800,



                color: AppColors.darkText,

              ),

            ),



            const SizedBox(height: 9),



            const Text(

              'Create a profile for yourself or a family member to start organizing health information.',



              textAlign: TextAlign.center,



              style: TextStyle(

                fontSize: 14,



                height: 1.5,



                color: AppColors.secondaryText,

              ),

            ),



            const SizedBox(height: 26),



            SizedBox(

              height: 52,



              child: ElevatedButton.icon(

                onPressed: onAddMember,



                icon: const Icon(Icons.person_add_alt_1_rounded),



                label: const Text(

                  'Add First Member',



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



class _ErrorState extends StatelessWidget {

  final VoidCallback onRetry;



  const _ErrorState({required this.onRetry});



  @override

  Widget build(BuildContext context) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(30),



        child: Column(

          mainAxisSize: MainAxisSize.min,



          children: [

            Container(

              width: 76,



              height: 76,



              decoration: BoxDecoration(

                color: AppColors.errorLight,



                borderRadius: BorderRadius.circular(22),

              ),



              child: const Icon(

                Icons.cloud_off_outlined,



                size: 36,



                color: AppColors.error,

              ),

            ),



            const SizedBox(height: 18),



            const Text(

              'Couldn’t load your family',



              textAlign: TextAlign.center,



              style: TextStyle(

                fontSize: 19,



                fontWeight: FontWeight.w700,



                color: AppColors.darkText,

              ),

            ),



            const SizedBox(height: 7),



            const Text(

              'Check your internet connection and try again.',



              textAlign: TextAlign.center,



              style: TextStyle(color: AppColors.secondaryText),

            ),



            const SizedBox(height: 20),



            OutlinedButton.icon(

              onPressed: onRetry,



              icon: const Icon(Icons.refresh_rounded),



              label: const Text('Try Again'),

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



  const _FieldLabel({required this.text});



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
