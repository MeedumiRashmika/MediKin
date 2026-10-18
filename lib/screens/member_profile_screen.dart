import 'package:flutter/material.dart';



import '../theme/app_colors.dart';



import 'doctors_screen.dart';



import 'doctor_visits_screen.dart';



import 'medicines_screen.dart';



import 'appointments_screen.dart';

import 'lab_reports_screen.dart';
import 'medical_history_screen.dart';



class MemberProfileScreen extends StatelessWidget {

  final String memberId;



  final String memberName;



  const MemberProfileScreen({

    super.key,



    required this.memberId,



    required this.memberName,

  });



  @override

  Widget build(BuildContext context) {

    final initial = memberName.trim().isNotEmpty

        ? memberName.trim()[0].toUpperCase()

        : '?';



    return Scaffold(

      appBar: AppBar(title: const Text('Health Profile')),



      body: SingleChildScrollView(

        padding: const EdgeInsets.fromLTRB(20, 8, 20, 35),



        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,



          children: [

            // =================================================



            // MEMBER HEADER



            // =================================================

            Container(

              width: double.infinity,



              padding: const EdgeInsets.all(20),



              decoration: BoxDecoration(

                color: AppColors.primary,



                borderRadius: BorderRadius.circular(24),

              ),



              child: Row(

                children: [

                  Container(

                    width: 68,



                    height: 68,



                    alignment: Alignment.center,



                    decoration: BoxDecoration(

                      color: AppColors.white,



                      borderRadius: BorderRadius.circular(20),

                    ),



                    child: Text(

                      initial,



                      style: const TextStyle(

                        fontSize: 27,



                        fontWeight: FontWeight.w800,



                        color: AppColors.primary,

                      ),

                    ),

                  ),



                  const SizedBox(width: 16),



                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,



                      children: [

                        Text(

                          memberName,



                          maxLines: 1,



                          overflow: TextOverflow.ellipsis,



                          style: const TextStyle(

                            fontSize: 22,



                            fontWeight: FontWeight.w800,



                            color: AppColors.white,

                          ),

                        ),



                        const SizedBox(height: 5),



                        Text(

                          'Family health profile',



                          style: TextStyle(

                            fontSize: 13,



                            color: Colors.white.withValues(alpha: 0.82),

                          ),

                        ),



                        const SizedBox(height: 11),



                        Container(

                          padding: const EdgeInsets.symmetric(

                            horizontal: 10,



                            vertical: 6,

                          ),



                          decoration: BoxDecoration(

                            color: Colors.white.withValues(alpha: 0.16),



                            borderRadius: BorderRadius.circular(20),

                          ),



                          child: const Row(

                            mainAxisSize: MainAxisSize.min,



                            children: [

                              Icon(

                                Icons.shield_outlined,



                                size: 14,



                                color: AppColors.white,

                              ),



                              SizedBox(width: 5),



                              Text(

                                'Health records',



                                style: TextStyle(

                                  fontSize: 11,



                                  fontWeight: FontWeight.w600,



                                  color: AppColors.white,

                                ),

                              ),

                            ],

                          ),

                        ),

                      ],

                    ),

                  ),

                ],

              ),

            ),



            const SizedBox(height: 28),



            // =================================================



            // UPCOMING CARE



            // =================================================

            const Text(

              'Upcoming Care',



              style: TextStyle(

                fontSize: 19,



                fontWeight: FontWeight.w700,



                color: AppColors.darkText,

              ),

            ),



            const SizedBox(height: 13),



            Container(

              width: double.infinity,



              padding: const EdgeInsets.all(17),



              decoration: BoxDecoration(

                color: AppColors.warningLight.withValues(alpha: 0.45),



                borderRadius: BorderRadius.circular(19),



                border: Border.all(

                  color: AppColors.warning.withValues(alpha: 0.35),

                ),

              ),



              child: const Row(

                children: [

                  _ProfileIconBox(

                    icon: Icons.notifications_none_rounded,



                    backgroundColor: AppColors.white,



                    iconColor: Color(0xFFC28A00),

                  ),



                  SizedBox(width: 14),



                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,



                      children: [

                        Text(

                          'No upcoming reminders',



                          style: TextStyle(

                            fontSize: 15,



                            fontWeight: FontWeight.w700,



                            color: AppColors.darkText,

                          ),

                        ),



                        SizedBox(height: 4),



                        Text(

                          'Appointments and medicine reminders will appear here.',



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



            const SizedBox(height: 30),



            // =================================================



            // CARE & TREATMENT



            // =================================================

            const Text(

              'Care & Treatment',



              style: TextStyle(

                fontSize: 19,



                fontWeight: FontWeight.w700,



                color: AppColors.darkText,

              ),

            ),



            const SizedBox(height: 14),



            // =================================================



            // DOCTORS + VISITS



            // =================================================

            Row(

              children: [

                Expanded(

                  child: _ProfileFeatureCard(

                    title: 'Doctors',



                    subtitle: 'Care team',



                    icon: Icons.medical_services_outlined,



                    iconBackground: AppColors.successLight,



                    iconColor: AppColors.success,



                    onTap: () {

                      Navigator.push(

                        context,



                        MaterialPageRoute(

                          builder: (context) => DoctorsScreen(

                            memberId: memberId,



                            memberName: memberName,

                          ),

                        ),

                      );

                    },

                  ),

                ),



                const SizedBox(width: 13),



                Expanded(

                  child: _ProfileFeatureCard(

                    title: 'Visits',



                    subtitle: 'Doctor visits',



                    icon: Icons.local_hospital_outlined,



                    iconBackground: AppColors.primaryVeryLight,



                    iconColor: AppColors.primary,



                    onTap: () {

                      Navigator.push(

                        context,



                        MaterialPageRoute(

                          builder: (context) => DoctorVisitsScreen(

                            memberId: memberId,



                            memberName: memberName,

                          ),

                        ),

                      );

                    },

                  ),

                ),

              ],

            ),



            const SizedBox(height: 13),



            // =================================================



            // MEDICINES + APPOINTMENTS



            // =================================================

            Row(

              children: [

                Expanded(

                  child: _ProfileFeatureCard(

                    title: 'Medicines',



                    subtitle: 'Medications',



                    icon: Icons.medication_outlined,



                    iconBackground: AppColors.warningLight,



                    iconColor: const Color(0xFFC28A00),



                    onTap: () {

                      Navigator.push(

                        context,



                        MaterialPageRoute(

                          builder: (context) => MedicinesScreen(

                            memberId: memberId,



                            memberName: memberName,

                          ),

                        ),

                      );

                    },

                  ),

                ),



                const SizedBox(width: 13),



                Expanded(

                  child: _ProfileFeatureCard(

                    title: 'Appointments',



                    subtitle: 'Schedule',



                    icon: Icons.calendar_month_outlined,



                    iconBackground: AppColors.primaryVeryLight,



                    iconColor: AppColors.primary,



                    onTap: () {

                      Navigator.push(

                        context,



                        MaterialPageRoute(

                          builder: (context) => AppointmentsScreen(

                            memberId: memberId,



                            memberName: memberName,

                          ),

                        ),

                      );

                    },

                  ),

                ),

              ],

            ),



            const SizedBox(height: 30),



            // =================================================



            // HEALTH RECORDS



            // =================================================

            const Text(

              'Health Records',



              style: TextStyle(

                fontSize: 19,



                fontWeight: FontWeight.w700,



                color: AppColors.darkText,

              ),

            ),



            const SizedBox(height: 14),



            // =================================================



            // LAB REPORTS



            // =================================================

            _ProfileListCard(

              title: 'Lab Reports',



              subtitle: 'Store test reports and results',



              icon: Icons.science_outlined,



              iconBackground: AppColors.successLight,



              iconColor: AppColors.success,



              onTap: () {

                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder: (context) => LabReportsScreen(

                      memberId: memberId,

                      memberName: memberName,

                    ),

                  ),

                );

              },

            ),



            const SizedBox(height: 12),



            // =================================================



            // MEDICAL HISTORY



            // =================================================

            _ProfileListCard(

              title: 'Medical History',



              subtitle: 'Previous health records and treatments',



              icon: Icons.history_rounded,



              iconBackground: AppColors.primaryVeryLight,



              iconColor: AppColors.primary,



              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicalHistoryScreen(
                      memberId: memberId,
                      memberName: memberName,
                    ),
                  ),
                );
              },

            ),



            const SizedBox(height: 25),

          ],

        ),

      ),

    );

  }



  // ===========================================================



  // COMING SOON MESSAGE



  // ===========================================================



  void _comingSoon(BuildContext context, String feature) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text('$feature will be connected next.'),



        behavior: SnackBarBehavior.floating,

      ),

    );

  }

}



// =============================================================



// FEATURE CARD



// =============================================================



class _ProfileFeatureCard extends StatelessWidget {

  final String title;



  final String subtitle;



  final IconData icon;



  final Color iconBackground;



  final Color iconColor;



  final VoidCallback onTap;



  const _ProfileFeatureCard({

    required this.title,



    required this.subtitle,



    required this.icon,



    required this.iconBackground,



    required this.iconColor,



    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return Card(

      child: InkWell(

        onTap: onTap,



        borderRadius: BorderRadius.circular(20),



        child: Padding(

          padding: const EdgeInsets.all(16),



          child: SizedBox(

            height: 118,



            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,



              children: [

                _ProfileIconBox(

                  icon: icon,



                  backgroundColor: iconBackground,



                  iconColor: iconColor,

                ),



                const Spacer(),



                Text(

                  title,



                  maxLines: 1,



                  overflow: TextOverflow.ellipsis,



                  style: const TextStyle(

                    fontSize: 15,



                    fontWeight: FontWeight.w700,



                    color: AppColors.darkText,

                  ),

                ),



                const SizedBox(height: 3),



                Text(

                  subtitle,



                  maxLines: 1,



                  overflow: TextOverflow.ellipsis,



                  style: const TextStyle(

                    fontSize: 11,



                    color: AppColors.secondaryText,

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}



// =============================================================



// HEALTH RECORD LIST CARD



// =============================================================



class _ProfileListCard extends StatelessWidget {

  final String title;



  final String subtitle;



  final IconData icon;



  final Color iconBackground;



  final Color iconColor;



  final VoidCallback onTap;



  const _ProfileListCard({

    required this.title,



    required this.subtitle,



    required this.icon,



    required this.iconBackground,



    required this.iconColor,



    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return Card(

      child: InkWell(

        onTap: onTap,



        borderRadius: BorderRadius.circular(20),



        child: Padding(

          padding: const EdgeInsets.all(16),



          child: Row(

            children: [

              _ProfileIconBox(

                icon: icon,



                backgroundColor: iconBackground,



                iconColor: iconColor,

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



// ICON BOX



// =============================================================



class _ProfileIconBox extends StatelessWidget {

  final IconData icon;



  final Color backgroundColor;



  final Color iconColor;



  const _ProfileIconBox({

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



      child: Icon(icon, size: 24, color: iconColor),

    );

  }

}
