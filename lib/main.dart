import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/notification_service.dart';

import 'services/pin_service.dart';

import 'screens/pin_screen.dart';

import 'screens/login_screen.dart';

import 'screens/family_members_screen.dart';

import 'screens/doctors_screen.dart';

import 'screens/doctor_visits_screen.dart';

import 'screens/medicines_screen.dart';

import 'screens/appointments_screen.dart';

import 'screens/lab_reports_screen.dart';

import 'screens/medical_history_screen.dart';

import 'theme/app_colors.dart';

import 'theme/app_theme.dart';

// =============================================================

// APP START

// =============================================================

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase

  await Firebase.initializeApp();

  // Initialize local notifications

  await NotificationService.instance.initialize();

  runApp(const MediFamilyApp());

}

// =============================================================

// MAIN APP

// =============================================================

class MediFamilyApp extends StatelessWidget {

  const MediFamilyApp({super.key});

  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'MediKIN',

      theme: AppTheme.lightTheme,

      home: const AuthGate(),

    );

  }

}

// =============================================================

// AUTH GATE

// =============================================================

class AuthGate extends StatefulWidget {

  const AuthGate({super.key});

  @override

  State<AuthGate> createState() => _AuthGateState();

}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {

  bool _unlocked = false;

  String? _uid;

  bool _wasBackgrounded = false;

  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

  }

  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

  }

  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.paused ||

        state == AppLifecycleState.hidden) {

      _wasBackgrounded = true;

    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {

      _wasBackgrounded = false;

      if (mounted) setState(() => _unlocked = false);

    }

  }

  @override

  Widget build(BuildContext context) {

    return StreamBuilder<User?>(

      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {

          return const Scaffold(

            body: Center(child: CircularProgressIndicator()),

          );

        }

        final user = snapshot.data;

        if (user == null) {

          _uid = null;

          _unlocked = false;

          return const LoginScreen();

        }

        if (_uid != user.uid) {

          _uid = user.uid;

          _unlocked = false;

        }

        if (_unlocked) return const HomeScreen();

        return FutureBuilder<bool>(

          key: ValueKey('pin-check-${user.uid}'),

          future: PinService.instance.hasPin(user.uid),

          builder: (context, pinSnapshot) {

            if (!pinSnapshot.hasData) {

              if (pinSnapshot.hasError) {

                return Scaffold(

                  body: Center(

                    child: Text(

                      'Unable to access secure PIN storage. Please restart the app.',

                    ),

                  ),

                );

              }

              return const Scaffold(

                body: Center(child: CircularProgressIndicator()),

              );

            }

            return PinScreen(

              key: ValueKey('pin-screen-${user.uid}-${pinSnapshot.data}'),

              uid: user.uid,

              isSetup: !pinSnapshot.data!,

              onUnlocked: () {

                if (mounted &&

                    FirebaseAuth.instance.currentUser?.uid == user.uid) {

                  setState(() => _unlocked = true);

                }

              },

            );

          },

        );

      },

    );

  }

}

// =============================================================

// HOME SCREEN

// =============================================================

class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key});

  String _getUserName() {

    final user = FirebaseAuth.instance.currentUser;

    final displayName = user?.displayName?.trim();

    if (displayName != null && displayName.isNotEmpty) {

      return displayName.split(' ').first;

    }

    return 'there';

  }

  Future<void> _logout(BuildContext context) async {

    final shouldLogout = await showDialog<bool>(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: const Text('Sign out?'),

          content: const Text(

            'You will need your email and password to sign in again.',

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context, false);

              },

              child: const Text('Cancel'),

            ),

            TextButton(

              onPressed: () {

                Navigator.pop(context, true);

              },

              child: const Text(

                'Sign Out',

                style: TextStyle(color: AppColors.error),

              ),

            ),

          ],

        );

      },

    );

    if (shouldLogout == true) {

      await PinService.instance.clearForUser(

        FirebaseAuth.instance.currentUser!.uid,

      );

      await FirebaseAuth.instance.signOut();

    }

  }

  Future<void> _sendPasswordReset(BuildContext context) async {

    final user = FirebaseAuth.instance.currentUser;

    final email = user?.email;

    if (email == null || email.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Unable to find your registered email address.'),

        ),

      );

      return;

    }

    try {

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Password reset email sent to $email')),

      );

    } on FirebaseAuthException catch (e) {

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(e.message ?? 'Unable to send password reset email.'),

        ),

      );

    }

  }

  Future<bool> _verifyCurrentPassword(

    BuildContext context,

    String password,

  ) async {

    final user = FirebaseAuth.instance.currentUser;

    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Unable to verify your account.')),

      );

      return false;

    }

    if (password.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Please enter your current password.')),

      );

      return false;

    }

    try {

      final credential = EmailAuthProvider.credential(

        email: email,

        password: password,

      );

      await user.reauthenticateWithCredential(credential);

      return true;

    } on FirebaseAuthException catch (e) {

      if (!context.mounted) return false;

      String message = 'Unable to verify password.';

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {

        message = 'Incorrect password. Please try again.';

      } else if (e.code == 'too-many-requests') {

        message = 'Too many attempts. Please try again later.';

      }

      ScaffoldMessenger.of(context)

          .showSnackBar(SnackBar(content: Text(message)));

      return false;

    }

  }

  // Delete a collection in small batches (Firestore batches have a limit).

  Future<void> _deleteCollectionDocuments(

    CollectionReference<Map<String, dynamic>> collection,

  ) async {

    final firestore = FirebaseFirestore.instance;

    while (true) {

      final snapshot = await collection.limit(200).get();

      if (snapshot.docs.isEmpty) return;

      final batch = firestore.batch();

      for (final document in snapshot.docs) {

        batch.delete(document.reference);

      }

      await batch.commit();

    }

  }

  // Called only after the current password has been verified.

  Future<void> _deleteAccountDataAndAuth(User user) async {

    final auth = FirebaseAuth.instance;

    if (auth.currentUser?.uid != user.uid) {

      throw StateError('The signed-in account has changed.');

    }

    final firestore = FirebaseFirestore.instance;

    final userRef = firestore.collection('users').doc(user.uid);

    final membersRef = userRef.collection('familyMembers');

    // Stop reminders scheduled on this phone.

    await NotificationService.instance.cancelAllNotifications();

    // Delete children before parents; deleting a Firestore document alone

    // does not delete its subcollections.

    while (true) {

      final members = await membersRef.limit(50).get();

      if (members.docs.isEmpty) break;

      for (final member in members.docs) {

        final memberRef = member.reference;

        final visitsRef = memberRef.collection('visits');

        while (true) {

          final visits = await visitsRef.limit(50).get();

          if (visits.docs.isEmpty) break;

          for (final visit in visits.docs) {

            await _deleteCollectionDocuments(

              visit.reference.collection('medicines'),

            );

            await visit.reference.delete();

          }

        }

        await _deleteCollectionDocuments(memberRef.collection('appointments'));

        await _deleteCollectionDocuments(memberRef.collection('doctors'));

        await _deleteCollectionDocuments(memberRef.collection('labReports'));

        await memberRef.delete();

      }

    }

    await userRef.delete();

    // Authentication must be deleted last, while Firestore is accessible.

    await user.delete();

    await PinService.instance.clearForUser(user.uid);

  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {

    final passwordController = TextEditingController();

    await showDialog<void>(

      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {

        bool obscurePassword = true;

        bool isChecking = false;

        String? errorMessage;

        return StatefulBuilder(

          builder: (context, setDialogState) {

            return AlertDialog(

              title: const Text('Delete account?'),

              content: Column(

                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const Text(

                    'This will permanently delete your MediKIN account '

                    'and all family health data. This action cannot be undone.',

                  ),

                  const SizedBox(height: 18),

                  TextField(

                    controller: passwordController,

                    obscureText: obscurePassword,

                    enabled: !isChecking,

                    decoration: InputDecoration(

                      labelText: 'Current password',

                      prefixIcon: const Icon(Icons.lock_outline_rounded),

                      suffixIcon: IconButton(

                        onPressed: isChecking

                            ? null

                            : () {

                                setDialogState(() {

                                  obscurePassword = !obscurePassword;

                                });

                              },

                        icon: Icon(

                          obscurePassword

                              ? Icons.visibility_outlined

                              : Icons.visibility_off_outlined,

                        ),

                      ),

                    ),

                  ),

                  if (errorMessage != null) ...[

                    const SizedBox(height: 8),

                    Text(

                      errorMessage!,

                      style: const TextStyle(

                        color: AppColors.error,

                        fontSize: 13,

                      ),

                    ),

                  ],

                  const SizedBox(height: 6),

                  Align(

                    alignment: Alignment.centerRight,

                    child: TextButton(

                      onPressed: isChecking

                          ? null

                          : () async {

                              Navigator.pop(dialogContext);

                              await _sendPasswordReset(context);

                            },

                      child: const Text('Forgot Password?'),

                    ),

                  ),

                ],

              ),

              actions: [

                TextButton(

                  onPressed: isChecking

                      ? null

                      : () {

                          Navigator.pop(dialogContext);

                        },

                  child: const Text('Cancel'),

                ),

                TextButton(

                  onPressed: isChecking

                      ? null

                      : () async {

                          final password = passwordController.text.trim();

                          if (password.isEmpty) {

                            setDialogState(() {

                              errorMessage =

                                  'Please enter your current password.';

                            });

                            return;

                          }

                          setDialogState(() {

                            isChecking = true;

                            errorMessage = null;

                          });

                          final verified = await _verifyCurrentPassword(

                            context,

                            password,

                          );

                          if (!dialogContext.mounted) return;

                          if (!verified) {

                            setDialogState(() {

                              isChecking = false;

                              errorMessage =

                                  'Incorrect password. Please try again.';

                            });

                            return;

                          }

                          final user = FirebaseAuth.instance.currentUser;

                          if (user == null) {

                            setDialogState(() {

                              isChecking = false;

                              errorMessage = 'No signed-in account found.';

                            });

                            return;

                          }

                          // Ask for a second, explicit confirmation before deleting data.

                          final confirmed = await showDialog<bool>(

                            context: dialogContext,

                            barrierDismissible: false,

                            builder: (confirmContext) => AlertDialog(

                              title: const Text('Permanently delete account?'),

                              content: const Text(

                                'Your MediKIN account and all family health '

                                'records will be permanently deleted. '

                                'This cannot be undone. Are you sure?',

                              ),

                              actions: [

                                TextButton(

                                  onPressed: () =>

                                      Navigator.pop(confirmContext, false),

                                  child: const Text('Cancel'),

                                ),

                                TextButton(

                                  onPressed: () =>

                                      Navigator.pop(confirmContext, true),

                                  child: const Text(

                                    'Yes, Delete Permanently',

                                    style: TextStyle(color: AppColors.error),

                                  ),

                                ),

                              ],

                            ),

                          );

                          if (!dialogContext.mounted) return;

                          if (confirmed != true) {

                            setDialogState(() {

                              isChecking = false;

                            });

                            return;

                          }

                          try {

                            await _deleteAccountDataAndAuth(user);

                            if (dialogContext.mounted) {

                              Navigator.pop(dialogContext);

                            }

                            // AuthGate automatically returns to LoginScreen.

                          } catch (e) {

                            if (!dialogContext.mounted) return;

                            setDialogState(() {

                              isChecking = false;

                              errorMessage =

                                  'Account deletion could not be completed. '

                                  'Check your internet connection and try again. '

                                  'Some records may already have been deleted.';

                            });

                            debugPrint('Delete account failed: $e');

                          }

                        },

                  child: isChecking

                      ? const SizedBox(

                          width: 20,

                          height: 20,

                          child: CircularProgressIndicator(strokeWidth: 2),

                        )

                      : const Text(

                          'Delete Account',

                          style: TextStyle(color: AppColors.error),

                        ),

                ),

              ],

            );

          },

        );

      },

    );

  }

  Future<Map<String, String>?> _selectFamilyMember(

    BuildContext context,

    String featureName,

  ) async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    try {

      final snapshot = await FirebaseFirestore.instance

          .collection('users')

          .doc(user.uid)

          .collection('familyMembers')

          .orderBy('createdAt')

          .get();

      if (!context.mounted) return null;

      if (snapshot.docs.isEmpty) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('Please add a family member first.'),

            behavior: SnackBarBehavior.floating,

          ),

        );

        return null;

      }

      return showModalBottomSheet<Map<String, String>>(

        context: context,

        backgroundColor: Colors.transparent,

        builder: (sheetContext) {

          return Container(

            decoration: const BoxDecoration(

              color: AppColors.background,

              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),

            ),

            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),

            child: SafeArea(

              top: false,

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

                  const SizedBox(height: 20),

                  const Text(

                    'Select Family Member',

                    style: TextStyle(

                      fontSize: 21,

                      fontWeight: FontWeight.w700,

                      color: AppColors.darkText,

                    ),

                  ),

                  const SizedBox(height: 5),

                  Text(

                    'Choose whose $featureName you want to view.',

                    style: const TextStyle(color: AppColors.secondaryText),

                  ),

                  const SizedBox(height: 16),

                  Flexible(

                    child: ListView.separated(

                      shrinkWrap: true,

                      itemCount: snapshot.docs.length,

                      separatorBuilder: (_, __) => const SizedBox(height: 8),

                      itemBuilder: (context, index) {

                        final document = snapshot.docs[index];

                        final data = document.data();

                        final rawName = data['name']?.toString().trim();

                        final relationship = data['relationship']

                            ?.toString()

                            .trim();

                        final name = rawName == null || rawName.isEmpty

                            ? 'Family Member'

                            : rawName;

                        return Card(

                          child: ListTile(

                            leading: CircleAvatar(

                              backgroundColor: AppColors.primaryVeryLight,

                              child: Text(

                                name[0].toUpperCase(),

                                style: const TextStyle(

                                  color: AppColors.primary,

                                  fontWeight: FontWeight.w700,

                                ),

                              ),

                            ),

                            title: Text(

                              name,

                              style: const TextStyle(

                                fontWeight: FontWeight.w700,

                                color: AppColors.darkText,

                              ),

                            ),

                            subtitle:

                                relationship == null || relationship.isEmpty

                                ? null

                                : Text(relationship),

                            trailing: const Icon(

                              Icons.arrow_forward_ios_rounded,

                              size: 15,

                              color: AppColors.secondaryText,

                            ),

                            onTap: () => Navigator.pop(sheetContext, {

                              'id': document.id,

                              'name': name,

                            }),

                          ),

                        );

                      },

                    ),

                  ),

                ],

              ),

            ),

          );

        },

      );

    } catch (_) {

      if (!context.mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Unable to load family members.'),

          behavior: SnackBarBehavior.floating,

        ),

      );

      return null;

    }

  }

  Future<void> _openDoctors(BuildContext context) async {

    final member = await _selectFamilyMember(context, 'doctors');

    if (member == null || !context.mounted) return;

    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) =>

            DoctorsScreen(memberId: member['id']!, memberName: member['name']!),

      ),

    );

  }

  Future<void> _openMedicines(BuildContext context) async {

    final member = await _selectFamilyMember(context, 'medicines');

    if (member == null || !context.mounted) return;

    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => MedicinesScreen(

          memberId: member['id']!,

          memberName: member['name']!,

        ),

      ),

    );

  }

  Future<void> _openAppointments(BuildContext context) async {

    final member = await _selectFamilyMember(context, 'appointments');

    if (member == null || !context.mounted) return;

    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => AppointmentsScreen(

          memberId: member['id']!,

          memberName: member['name']!,

        ),

      ),

    );

  }

  Future<void> _openLabReports(BuildContext context) async {

    final member = await _selectFamilyMember(context, 'lab reports');

    if (member == null || !context.mounted) return;

    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => LabReportsScreen(

          memberId: member['id']!,

          memberName: member['name']!,

        ),

      ),

    );

  }

  Future<void> _openMedicalHistory(BuildContext context) async {

    final member = await _selectFamilyMember(context, 'medical history');

    if (member == null || !context.mounted) return;

    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => MedicalHistoryScreen(

          memberId: member['id']!,

          memberName: member['name']!,

        ),

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    final userName = _getUserName();

    return Scaffold(

      backgroundColor: AppColors.background,

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                children: [

                  Container(

                    width: 46,

                    height: 46,

                    decoration: BoxDecoration(

                      gradient: const LinearGradient(

                        colors: [AppColors.primary, AppColors.primaryDark],

                        begin: Alignment.topLeft,

                        end: Alignment.bottomRight,

                      ),

                      borderRadius: BorderRadius.circular(15),

                      boxShadow: [

                        BoxShadow(

                          color: AppColors.primary.withValues(alpha: 0.18),

                          blurRadius: 18,

                          offset: const Offset(0, 7),

                        ),

                      ],

                    ),

                    child: const Icon(

                      Icons.health_and_safety_rounded,

                      color: Colors.white,

                      size: 26,

                    ),

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                       RichText(

  text: const TextSpan(

    style: TextStyle(

      fontSize: 24,

      fontWeight: FontWeight.w800,

      letterSpacing: -0.5,

    ),

    children: [

      TextSpan(

        text: 'Medi',

        style: TextStyle(

          color: AppColors.primary,

        ),

      ),

      TextSpan(

        text: 'KIN',

        style: TextStyle(

          color: AppColors.coral,

          fontStyle: FontStyle.italic,

        ),

      ),

    ],

  ),

),

                        const SizedBox(height: 2),

                        const Text(

                          'Your Family Health Companion',

                          style: TextStyle(

                            fontSize: 11.5,

                            color: AppColors.secondaryText,

                          ),

                        ),

                      ],

                    ),

                  ),

                  PopupMenuButton<String>(

                    tooltip: 'Account',

                    offset: const Offset(0, 48),

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(16),

                    ),

                    icon: Container(

                      width: 42,

                      height: 42,

                      decoration: BoxDecoration(

                        color: Colors.white,

                        shape: BoxShape.circle,

                        border: Border.all(color: AppColors.border),

                        boxShadow: const [

                          BoxShadow(

                            color: Color(0x0D1B2A4A),

                            blurRadius: 12,

                            offset: Offset(0, 4),

                          ),

                        ],

                      ),

                      child: Center(

                        child: Text(

                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',

                          style: const TextStyle(

                            color: AppColors.primary,

                            fontSize: 17,

                            fontWeight: FontWeight.w800,

                          ),

                        ),

                      ),

                    ),

                    onSelected: (value) {

                      if (value == 'logout') {

                        _logout(context);

                      } else if (value == 'deleteAccount') {

                        _showDeleteAccountDialog(context);

                      }

                    },

                    itemBuilder: (_) => const [

                      PopupMenuItem(

                        value: 'logout',

                        child: Row(

                          children: [

                            Icon(Icons.logout_rounded, size: 20),

                            SizedBox(width: 10),

                            Text('Sign Out'),

                          ],

                        ),

                      ),

                      PopupMenuDivider(),

                      PopupMenuItem(

                        value: 'deleteAccount',

                        child: Row(

                          children: [

                            Icon(

                              Icons.delete_forever_outlined,

                              size: 20,

                              color: AppColors.error,

                            ),

                            SizedBox(width: 10),

                            Text(

                              'Delete Account',

                              style: TextStyle(color: AppColors.error),

                            ),

                          ],

                        ),

                      ),

                    ],

                  ),

                ],

              ),

              const SizedBox(height: 26),

              Container(

                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(20, 22, 18, 20),

                decoration: BoxDecoration(

                  gradient: const LinearGradient(

                    colors: [AppColors.primaryVeryLight, AppColors.coralVeryLight],

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                  ),

                  borderRadius: BorderRadius.circular(26),

                  border: Border.all(color: AppColors.border),

                ),

                child: Row(

                  children: [

                    Expanded(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            'Hi, $userName 👋',

                            style: const TextStyle(

                              fontSize: 13,

                              fontWeight: FontWeight.w600,

                              color: AppColors.primary,

                            ),

                          ),

                          const SizedBox(height: 7),

                          const Text(

                            'Your family’s health,\nall in one place.',

                            style: TextStyle(

                              fontSize: 23,

                              height: 1.16,

                              fontWeight: FontWeight.w800,

                              letterSpacing: -0.5,

                              color: AppColors.darkText,

                            ),

                          ),

                          const SizedBox(height: 9),

                          const Text(

                            'Stay on top of medicines, appointments and health records.',

                            style: TextStyle(

                              fontSize: 12.5,

                              height: 1.45,

                              color: AppColors.secondaryText,

                            ),

                          ),

                        ],

                      ),

                    ),

                    const SizedBox(width: 12),

                    Container(

                      width: 88,

                      height: 112,

                      decoration: BoxDecoration(

                        color: Colors.white.withValues(alpha: 0.72),

                        borderRadius: BorderRadius.circular(24),

                      ),

                      child: Stack(

                        alignment: Alignment.center,

                        children: [

                          Positioned(

                            top: 13,

                            right: 11,

                            child: Icon(

                              Icons.favorite_rounded,

                              size: 19,

                              color: AppColors.coral

                                  .withValues(alpha: 0.75),

                            ),

                          ),

                          const Icon(

                            Icons.family_restroom_rounded,

                            size: 48,

                            color: AppColors.primary,

                          ),

                          const Positioned(

                            bottom: 13,

                            right: 10,

                            child: CircleAvatar(

                              radius: 15,

                              backgroundColor: AppColors.successLight,

                              child: Icon(

                                Icons.add_rounded,

                                size: 20,

                                color: AppColors.success,

                              ),

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 26),

              const _HomeSectionTitle(

                title: 'Health Overview',

                subtitle: 'Your nearest medicines, appointments and follow-ups',

              ),

              const SizedBox(height: 13),

              const HomeHealthOverview(),

              const SizedBox(height: 28),

              const _HomeSectionTitle(

                title: 'Quick Actions',

                subtitle: 'Everything you need, one tap away',

              ),

              const SizedBox(height: 14),

              GridView.count(

                crossAxisCount: 2,

                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                crossAxisSpacing: 12,

                mainAxisSpacing: 12,

                childAspectRatio: 1.42,

                children: [

                  HomeFeatureCard(

                    title: 'Family',

                    subtitle: 'Manage members',

                    icon: Icons.people_alt_rounded,

                    iconBackground: AppColors.primaryVeryLight,

                    iconColor: AppColors.primary,

                    onTap: () => Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) => const FamilyMembersScreen(),

                      ),

                    ),

                  ),

                  HomeFeatureCard(

                    title: 'Doctors',

                    subtitle: 'Your care team',

                    icon: Icons.medical_services_rounded,

                    iconBackground: AppColors.primaryVeryLight,

                    iconColor: AppColors.primaryDark,

                    onTap: () => _openDoctors(context),

                  ),

                  HomeFeatureCard(

                    title: 'Medicines',

                    subtitle: 'Track medication',

                    icon: Icons.medication_rounded,

                    iconBackground: AppColors.coralVeryLight,

                    iconColor: AppColors.coralDark,

                    onTap: () => _openMedicines(context),

                  ),

                  HomeFeatureCard(

                    title: 'Appointments',

                    subtitle: 'Visits & reminders',

                    icon: Icons.calendar_month_rounded,

                    iconBackground: AppColors.warningLight,

                    iconColor: AppColors.warning,

                    onTap: () => _openAppointments(context),

                  ),

                ],

              ),

              const SizedBox(height: 28),

              const _HomeSectionTitle(

                title: 'Health Records',

                subtitle: 'Keep important medical information organized',

              ),

              const SizedBox(height: 14),

              HomeListCard(

                icon: Icons.science_rounded,

                title: 'Lab Reports',

                subtitle: 'Store and review test reports',

                iconBackground: AppColors.coralVeryLight,

                iconColor: AppColors.coralDark,

                onTap: () => _openLabReports(context),

              ),

              const SizedBox(height: 11),

              HomeListCard(

                icon: Icons.history_rounded,

                title: 'Medical History',

                subtitle: 'Visits, medicines and previous records',

                iconBackground: AppColors.primaryVeryLight,

                iconColor: AppColors.primaryDark,

                onTap: () => _openMedicalHistory(context),

              ),

              const SizedBox(height: 8),

            ],

          ),

        ),

      ),

    );

  }

}

class _HomeSectionTitle extends StatelessWidget {

  final String title;

  final String subtitle;

  const _HomeSectionTitle({required this.title, required this.subtitle});

  @override

  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          title,

          style: const TextStyle(

            fontSize: 19,

            fontWeight: FontWeight.w800,

            letterSpacing: -0.25,

            color: AppColors.darkText,

          ),

        ),

        const SizedBox(height: 4),

        Text(

          subtitle,

          style: const TextStyle(

            fontSize: 12.5,

            height: 1.35,

            color: AppColors.secondaryText,

          ),

        ),

      ],

    );

  }

}

class HomeHealthOverview extends StatefulWidget {

  const HomeHealthOverview({super.key});

  @override

  State<HomeHealthOverview> createState() => _HomeHealthOverviewState();

}

class _HomeHealthOverviewState extends State<HomeHealthOverview> {

  late Future<List<_HomeCareItem>> _future;

  @override

  void initState() {

    super.initState();

    _future = _loadUpcomingCare();

  }

  Future<void> _refresh() async {

    setState(() {

      _future = _loadUpcomingCare();

    });

    await _future;

  }

  Future<List<_HomeCareItem>> _loadUpcomingCare() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return [];

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final items = <_HomeCareItem>[];

    final members = await FirebaseFirestore.instance

        .collection('users')

        .doc(user.uid)

        .collection('familyMembers')

        .get();

    for (final member in members.docs) {

      final memberData = member.data();

      final memberName = _text(memberData['name']).isEmpty

          ? 'Family Member'

          : _text(memberData['name']);

      final appointments = await member.reference

          .collection('appointments')

          .get();

      for (final appointment in appointments.docs) {

        final data = appointment.data();

        final date = _dateFrom(

          data['appointmentDate'] ?? data['dateTime'] ?? data['date'],

        );

        if (date == null || !date.isAfter(now)) continue;

        final doctorName = _firstText([

          data['doctorName'],

          data['doctor'],

          data['title'],

        ]);

        items.add(

          _HomeCareItem(

            type: _HomeCareType.appointment,

            dateTime: date,

            memberName: memberName,

            title: doctorName.isEmpty ? 'Appointment' : doctorName,

          ),

        );

      }

      final visits = await member.reference.collection('visits').get();

      for (final visit in visits.docs) {

        final visitData = visit.data();

        final nextVisit = _dateFrom(visitData['nextVisitDate']);

        if (nextVisit != null) {

          final day = DateTime(nextVisit.year, nextVisit.month, nextVisit.day);

          if (!day.isBefore(today)) {

            final doctorName = _firstText([visitData['doctorName']]);

            items.add(

              _HomeCareItem(

                type: _HomeCareType.nextVisit,

                dateTime: day.add(const Duration(hours: 9)),

                memberName: memberName,

                title: doctorName.isEmpty

                    ? 'Recommended doctor visit'

                    : doctorName,

              ),

            );

          }

        }

        final medicines = await visit.reference.collection('medicines').get();

        for (final medicine in medicines.docs) {

          final medicineData = medicine.data();

          if (medicineData['reminderEnabled'] != true) continue;

          final startDate = _dateFrom(medicineData['startDate']);

          final durationDays = _intFrom(

            medicineData['durationDays'] ?? medicineData['duration'],

          );

          if (startDate == null || durationDays <= 0) continue;

          final startDay = DateTime(

            startDate.year,

            startDate.month,

            startDate.day,

          );

          final endExclusive = startDay.add(Duration(days: durationDays));

          if (today.isBefore(startDay) || !today.isBefore(endExclusive)) {

            continue;

          }

          final reminderTimes = medicineData['reminderTimes'];

          if (reminderTimes is! List) continue;

          final medicineName = _text(medicineData['name']);

          for (final value in reminderTimes) {

            final time = _parseTime(value?.toString());

            if (time == null) continue;

            final doseTime = DateTime(

              now.year,

              now.month,

              now.day,

              time.$1,

              time.$2,

            );

            if (!doseTime.isAfter(now)) continue;

            items.add(

              _HomeCareItem(

                type: _HomeCareType.medicine,

                dateTime: doseTime,

                memberName: memberName,

                title: medicineName.isEmpty ? 'Medicine' : medicineName,

              ),

            );

          }

        }

      }

    }

    items.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return items.take(4).toList();

  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _firstText(List<dynamic> values) {

    for (final value in values) {

      final text = _text(value);

      if (text.isNotEmpty) return text;

    }

    return '';

  }

  static DateTime? _dateFrom(dynamic value) {

    if (value is Timestamp) return value.toDate();

    return null;

  }

  static int _intFrom(dynamic value) {

    if (value is int) return value;

    if (value is num) return value.toInt();

    final match = RegExp(r'\d+').firstMatch(value?.toString() ?? '');

    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;

  }

  static (int, int)? _parseTime(String? value) {

    if (value == null) return null;

    final parts = value.trim().split(':');

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

    return (hour, minute);

  }

  String _when(DateTime value) {

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final day = DateTime(value.year, value.month, value.day);

    final difference = day.difference(today).inDays;

    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

    final minute = value.minute.toString().padLeft(2, '0');

    final period = value.hour >= 12 ? 'PM' : 'AM';

    final time = '$hour:$minute $period';

    if (difference == 0) return 'Today • $time';

    if (difference == 1) return 'Tomorrow • $time';

    final d = value.day.toString().padLeft(2, '0');

    final m = value.month.toString().padLeft(2, '0');

    return '$d/$m/${value.year} • $time';

  }

  IconData _icon(_HomeCareType type) {

    switch (type) {

      case _HomeCareType.medicine:

        return Icons.medication_outlined;

      case _HomeCareType.appointment:

        return Icons.calendar_month_outlined;

      case _HomeCareType.nextVisit:

        return Icons.local_hospital_outlined;

    }

  }

  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: AppColors.primary,

        borderRadius: BorderRadius.circular(22),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 45,

                height: 45,

                decoration: BoxDecoration(

                  color: Colors.white.withValues(alpha: 0.16),

                  borderRadius: BorderRadius.circular(13),

                ),

                child: const Icon(

                  Icons.notifications_active_outlined,

                  color: AppColors.white,

                ),

              ),

              const Spacer(),

              Container(

                padding: const EdgeInsets.symmetric(

                  horizontal: 11,

                  vertical: 6,

                ),

                decoration: BoxDecoration(

                  color: Colors.white.withValues(alpha: 0.16),

                  borderRadius: BorderRadius.circular(20),

                ),

                child: const Text(

                  'Health Overview',

                  style: TextStyle(

                    fontSize: 11,

                    fontWeight: FontWeight.w600,

                    color: AppColors.white,

                  ),

                ),

              ),

              const SizedBox(width: 4),

              IconButton(

                tooltip: 'Refresh',

                onPressed: _refresh,

                icon: const Icon(

                  Icons.refresh_rounded,

                  color: AppColors.white,

                  size: 20,

                ),

              ),

            ],

          ),

          const SizedBox(height: 18),

          const Text(

            'Stay on track',

            style: TextStyle(

              fontSize: 21,

              fontWeight: FontWeight.w700,

              color: AppColors.white,

            ),

          ),

          const SizedBox(height: 6),

          Text(

            'Your next medicines, appointments and follow-up visits.',

            style: TextStyle(

              fontSize: 13,

              height: 1.45,

              color: Colors.white.withValues(alpha: 0.85),

            ),

          ),

          const SizedBox(height: 16),

          FutureBuilder<List<_HomeCareItem>>(

            future: _future,

            builder: (context, snapshot) {

              if (snapshot.connectionState == ConnectionState.waiting) {

                return const Center(

                  child: Padding(

                    padding: EdgeInsets.all(10),

                    child: SizedBox(

                      width: 24,

                      height: 24,

                      child: CircularProgressIndicator(

                        strokeWidth: 2.4,

                        color: AppColors.white,

                      ),

                    ),

                  ),

                );

              }

              if (snapshot.hasError) {

                return const Text(

                  'Couldn’t load upcoming care. Tap refresh to try again.',

                  style: TextStyle(fontSize: 13, color: AppColors.white),

                );

              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {

                return _OverviewEmpty();

              }

              return Column(

                children: [

                  for (var i = 0; i < items.length; i++) ...[

                    _OverviewRow(

                      icon: _icon(items[i].type),

                      title: items[i].title,

                      memberName: items[i].memberName,

                      when: _when(items[i].dateTime),

                    ),

                    if (i != items.length - 1) const SizedBox(height: 8),

                  ],

                ],

              );

            },

          ),

        ],

      ),

    );

  }

}

enum _HomeCareType { medicine, appointment, nextVisit }

class _HomeCareItem {

  final _HomeCareType type;

  final DateTime dateTime;

  final String memberName;

  final String title;

  const _HomeCareItem({

    required this.type,

    required this.dateTime,

    required this.memberName,

    required this.title,

  });

}

class _OverviewEmpty extends StatelessWidget {

  const _OverviewEmpty();

  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: Colors.white.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(15),

      ),

      child: const Text(

        'No upcoming care right now.',

        style: TextStyle(

          fontSize: 13,

          fontWeight: FontWeight.w600,

          color: AppColors.white,

        ),

      ),

    );

  }

}

class _OverviewRow extends StatelessWidget {

  final IconData icon;

  final String title;

  final String memberName;

  final String when;

  const _OverviewRow({

    required this.icon,

    required this.title,

    required this.memberName,

    required this.when,

  });

  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(

        color: Colors.white.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(15),

      ),

      child: Row(

        children: [

          Container(

            width: 38,

            height: 38,

            decoration: BoxDecoration(

              color: Colors.white.withValues(alpha: 0.16),

              borderRadius: BorderRadius.circular(11),

            ),

            child: Icon(icon, size: 20, color: AppColors.white),

          ),

          const SizedBox(width: 11),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(

                    fontSize: 13,

                    fontWeight: FontWeight.w700,

                    color: AppColors.white,

                  ),

                ),

                const SizedBox(height: 2),

                Text(

                  memberName,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(

                    fontSize: 11,

                    color: Colors.white.withValues(alpha: 0.76),

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(width: 8),

          Text(

            when,

            textAlign: TextAlign.right,

            style: const TextStyle(

              fontSize: 10,

              fontWeight: FontWeight.w600,

              color: AppColors.white,

            ),

          ),

        ],

      ),

    );

  }

}

// =============================================================

// HOME FEATURE CARD

// =============================================================

class HomeFeatureCard extends StatelessWidget {

  final String title;

  final String subtitle;

  final IconData icon;

  final Color iconBackground;

  final Color iconColor;

  final VoidCallback? onTap;

  const HomeFeatureCard({

    super.key,

    required this.title,

    required this.subtitle,

    required this.icon,

    required this.iconBackground,

    required this.iconColor,

    this.onTap,

  });

  @override

  Widget build(BuildContext context) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: AppColors.border),

        boxShadow: const [

          BoxShadow(

            color: Color(0x0A1B2A4A),

            blurRadius: 14,

            offset: Offset(0, 5),

          ),

        ],

      ),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Padding(

          padding: const EdgeInsets.all(17),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Container(

                width: 45,

                height: 45,

                decoration: BoxDecoration(

                  color: iconBackground,

                  borderRadius: BorderRadius.circular(13),

                ),

                child: Icon(icon, color: iconColor, size: 25),

              ),

              const Spacer(),

              Text(

                title,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.w700,

                  color: AppColors.darkText,

                ),

              ),

              const SizedBox(height: 4),

              Text(

                subtitle,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(

                  fontSize: 12,

                  color: AppColors.secondaryText,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}

// =============================================================

// HOME LIST CARD

// =============================================================

class HomeListCard extends StatelessWidget {

  final IconData icon;

  final String title;

  final String subtitle;

  final Color iconBackground;

  final Color iconColor;

  final VoidCallback? onTap;

  const HomeListCard({

    super.key,

    required this.icon,

    required this.title,

    required this.subtitle,

    required this.iconBackground,

    required this.iconColor,

    this.onTap,

  });

  @override

  Widget build(BuildContext context) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: AppColors.border),

        boxShadow: const [

          BoxShadow(

            color: Color(0x0A1B2A4A),

            blurRadius: 14,

            offset: Offset(0, 5),

          ),

        ],

      ),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Row(

            children: [

              Container(

                width: 50,

                height: 50,

                decoration: BoxDecoration(

                  color: iconBackground,

                  borderRadius: BorderRadius.circular(15),

                ),

                child: Icon(icon, color: iconColor, size: 26),

              ),

              const SizedBox(width: 14),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: const TextStyle(

                        fontSize: 15,

                        fontWeight: FontWeight.w700,

                        color: AppColors.darkText,

                      ),

                    ),

                    const SizedBox(height: 4),

                    Text(

                      subtitle,

                      style: const TextStyle(

                        fontSize: 12,

                        color: AppColors.secondaryText,

                      ),

                    ),

                  ],

                ),

              ),

              const Icon(

                Icons.arrow_forward_ios_rounded,

                size: 16,

                color: AppColors.secondaryText,

              ),

            ],

          ),

        ),

      ),

    );

  }

}
