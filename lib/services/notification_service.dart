import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:timezone/data/latest.dart' as tz;

import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ============================================================

  // INITIALIZE

  // ============================================================

  Future<void> initialize() async {
    // Load timezone database

    tz.initializeTimeZones();

    // Get phone timezone

    final localTimezone = await FlutterTimezone.getLocalTimezone();

    // Set local timezone

    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    // Android initialization

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings: initializationSettings);

    // Android 13+ notification permission

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // ============================================================

  // TEST NOTIFICATION

  // ============================================================

  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'medifamily_test_channel',

      'MediKIN Test Notifications',

      channelDescription: 'Used to test MediKIN notifications.',

      importance: Importance.high,

      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 100,

      title: 'MediKIN 💜',

      body: 'Medicine reminders are ready.',

      notificationDetails: notificationDetails,
    );
  }

  // ============================================================

  // SCHEDULE ONE MEDICINE REMINDER

  // ============================================================

  Future<void> scheduleMedicineReminder({
    required int notificationId,

    required String medicineName,

    required String dosage,

    required DateTime scheduledDate,
  }) async {
    final scheduledTime = tz.TZDateTime(
      tz.local,

      scheduledDate.year,

      scheduledDate.month,

      scheduledDate.day,

      scheduledDate.hour,

      scheduledDate.minute,
    );

    // Do not schedule notifications in the past

    if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'medifamily_medicine_channel',

      'Medicine Reminders',

      channelDescription: 'Reminders for medicines saved in MediKIN.',

      importance: Importance.high,

      priority: Priority.high,

      category: AndroidNotificationCategory.reminder,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    final dosageText = dosage.trim().isEmpty
        ? 'Time to take $medicineName.'
        : 'Time to take $medicineName ($dosage).';

    await _notifications.zonedSchedule(
      id: notificationId,

      title: '💊 Medicine Reminder',

      body: dosageText,

      scheduledDate: scheduledTime,

      notificationDetails: notificationDetails,

      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

      matchDateTimeComponents: null,
    );
  }

  // ============================================================

  // SCHEDULE MEDICINE COURSE

  // ============================================================

  Future<List<int>> scheduleMedicineCourse({
    required String medicineName,

    required String dosage,

    required DateTime startDate,

    required int durationDays,

    required List<DateTime> reminderTimes,

    required int baseNotificationId,
  }) async {
    final List<int> notificationIds = [];

    if (durationDays <= 0 || reminderTimes.isEmpty) {
      return notificationIds;
    }

    int notificationCounter = 0;

    for (int day = 0; day < durationDays; day++) {
      final courseDate = DateTime(
        startDate.year,

        startDate.month,

        startDate.day,
      ).add(Duration(days: day));

      for (final reminderTime in reminderTimes) {
        final scheduledDate = DateTime(
          courseDate.year,

          courseDate.month,

          courseDate.day,

          reminderTime.hour,

          reminderTime.minute,
        );

        final notificationId = baseNotificationId + notificationCounter;

        notificationCounter++;

        // Skip times that have already passed

        if (!scheduledDate.isAfter(DateTime.now())) {
          continue;
        }

        await scheduleMedicineReminder(
          notificationId: notificationId,

          medicineName: medicineName,

          dosage: dosage,

          scheduledDate: scheduledDate,
        );

        notificationIds.add(notificationId);
      }
    }

    return notificationIds;
  }

  // ============================================================

  // SCHEDULE ONE DOCTOR VISIT REMINDER

  // ============================================================

  Future<void> scheduleVisitReminder({
    required int notificationId,

    required String memberName,

    required String doctorName,

    required DateTime scheduledDate,

    required DateTime visitDate,

    required int daysBefore,
  }) async {
    final scheduledTime = tz.TZDateTime(
      tz.local,

      scheduledDate.year,

      scheduledDate.month,

      scheduledDate.day,

      scheduledDate.hour,

      scheduledDate.minute,
    );

    // Do not schedule a reminder in the past

    if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'medifamily_visit_channel',

      'Doctor Visit Reminders',

      channelDescription: 'Reminders for upcoming doctor visits in MediKIN.',

      importance: Importance.high,

      priority: Priority.high,

      category: AndroidNotificationCategory.reminder,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    final day = visitDate.day.toString().padLeft(2, '0');

    final month = visitDate.month.toString().padLeft(2, '0');

    final formattedVisitDate = '$day/$month/${visitDate.year}';

    await _notifications.zonedSchedule(
      id: notificationId,

      title: '🩺 Doctor Visit Reminder',

      body:
          '$memberName has a recommended visit with '
          '$doctorName on $formattedVisitDate '
          '($daysBefore days remaining).',

      scheduledDate: scheduledTime,

      notificationDetails: notificationDetails,

      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

      matchDateTimeComponents: null,
    );
  }

  // ============================================================

  // SCHEDULE NEXT DOCTOR VISIT REMINDERS

  // ============================================================

  Future<List<int>> scheduleVisitReminders({
    required String memberName,

    required String doctorName,

    required DateTime visitDate,

    required int baseNotificationId,
  }) async {
    final List<int> notificationIds = [];

    // MediKIN reminder plan

    // 14 days before

    // 7 days before

    // 3 days before

    const reminderDays = <int>[14, 7, 3];

    for (int index = 0; index < reminderDays.length; index++) {
      final daysBefore = reminderDays[index];

      // Reminder will be scheduled for 9:00 AM

      final scheduledDate = DateTime(
        visitDate.year,

        visitDate.month,

        visitDate.day,

        9,

        0,
      ).subtract(Duration(days: daysBefore));

      // Skip reminder dates that have already passed

      if (!scheduledDate.isAfter(DateTime.now())) {
        continue;
      }

      final notificationId = baseNotificationId + index;

      await scheduleVisitReminder(
        notificationId: notificationId,

        memberName: memberName,

        doctorName: doctorName,

        scheduledDate: scheduledDate,

        visitDate: visitDate,

        daysBefore: daysBefore,
      );

      notificationIds.add(notificationId);
    }

    return notificationIds;
  }

  // ============================================================

  // CANCEL ONE NOTIFICATION

  // ============================================================

  // ============================================================

  // APPOINTMENT REMINDERS

  // ============================================================

  Future<void> scheduleAppointmentReminder({
    required int notificationId,

    required String memberName,

    required String doctorName,

    required DateTime appointmentDateTime,

    required DateTime scheduledDate,

    required String reminderLabel,
  }) async {
    final scheduledTime = tz.TZDateTime(
      tz.local,

      scheduledDate.year,

      scheduledDate.month,

      scheduledDate.day,

      scheduledDate.hour,

      scheduledDate.minute,
    );

    if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'medifamily_appointment_channel',

      'Appointment Reminders',

      channelDescription: 'Reminders for booked appointments in MediKIN.',

      importance: Importance.high,

      priority: Priority.high,

      category: AndroidNotificationCategory.reminder,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    final day = appointmentDateTime.day.toString().padLeft(2, '0');

    final month = appointmentDateTime.month.toString().padLeft(2, '0');

    final hour = appointmentDateTime.hour.toString().padLeft(2, '0');

    final minute = appointmentDateTime.minute.toString().padLeft(2, '0');

    await _notifications.zonedSchedule(
      id: notificationId,

      title: '📅 Appointment Reminder',

      body:
          '$memberName has an appointment with $doctorName on '
          '$day/$month/${appointmentDateTime.year} at $hour:$minute '
          '($reminderLabel).',

      scheduledDate: scheduledTime,

      notificationDetails: notificationDetails,

      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

      matchDateTimeComponents: null,
    );
  }

  Future<List<int>> scheduleAppointmentReminders({
    required String memberName,

    required String doctorName,

    required DateTime appointmentDateTime,

    required int baseNotificationId,
  }) async {
    final List<int> notificationIds = [];

    final reminders = <({Duration before, String label})>[
      (before: const Duration(days: 1), label: '1 day remaining'),

      (before: const Duration(hours: 2), label: '2 hours remaining'),
    ];

    for (int index = 0; index < reminders.length; index++) {
      final reminder = reminders[index];

      final scheduledDate = appointmentDateTime.subtract(reminder.before);

      if (!scheduledDate.isAfter(DateTime.now())) {
        continue;
      }

      final notificationId = baseNotificationId + index;

      await scheduleAppointmentReminder(
        notificationId: notificationId,

        memberName: memberName,

        doctorName: doctorName,

        appointmentDateTime: appointmentDateTime,

        scheduledDate: scheduledDate,

        reminderLabel: reminder.label,
      );

      notificationIds.add(notificationId);
    }

    return notificationIds;
  }

  Future<void> cancelAppointmentReminders(List<int> notificationIds) async {
    for (final id in notificationIds) {
      await _notifications.cancel(id: id);
    }
  }

  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(id: notificationId);
  }

  // ============================================================

  // CANCEL MEDICINE REMINDERS

  // ============================================================

  Future<void> cancelMedicineReminders(List<int> notificationIds) async {
    for (final id in notificationIds) {
      await _notifications.cancel(id: id);
    }
  }

  // ============================================================

  // CANCEL DOCTOR VISIT REMINDERS

  // ============================================================

  Future<void> cancelVisitReminders(List<int> notificationIds) async {
    for (final id in notificationIds) {
      await _notifications.cancel(id: id);
    }
  }

  // ============================================================

  // CANCEL ALL NOTIFICATIONS

  // ============================================================

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
