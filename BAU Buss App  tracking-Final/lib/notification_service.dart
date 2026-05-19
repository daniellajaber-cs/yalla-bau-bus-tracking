//This file = your full notification system logic
//It handles:Push notifications (FCM), User settings (ON/OFF), Saving notifications in Firestore,Real-time updates,Read / unread tracking
// ===================== IMPORTS =====================

// Firestore for database
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase Auth to get current user
import 'package:firebase_auth/firebase_auth.dart';

// Firebase Messaging (FCM) for push notifications
import 'package:firebase_messaging/firebase_messaging.dart';

// For checking platform (web or mobile)
import 'package:flutter/foundation.dart';

// ===================== NOTIFICATION MODEL =====================
// Represents one notification item in the app
class UserNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final String route;
  final String tripId;
  final DateTime? createdAt;
  final bool isRead;

  UserNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.route,
    required this.tripId,
    required this.createdAt,
    required this.isRead,
  });

  // Convert Firestore data → object
  factory UserNotificationItem.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];

    return UserNotificationItem(
      id: id,
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      route: data['route']?.toString() ?? '',
      tripId: data['tripId']?.toString() ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      isRead: data['isRead'] == true,
    );
  }
}

// ===================== SETTINGS MODEL =====================
// Stores user notification preferences
class NotificationSettingsData {
  final bool pushNotifications; // general notifications ON/OFF
  final bool arrivalAlerts; // arrival alerts ON/OFF
  final String selectedStop; // user selected stop

  const NotificationSettingsData({
    required this.pushNotifications,
    required this.arrivalAlerts,
    required this.selectedStop,
  });
}

// ===================== MAIN SERVICE =====================
class NotificationService {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Get current user ID
  String? get _uid => _auth.currentUser?.uid;

  // ===================== USER DOCUMENT =====================
  // Reference to user's document in Firestore
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    return _firestore.collection('users').doc(uid);
  }

  // ===================== NOTIFICATIONS COLLECTION =====================
  // Reference to user's notifications collection
  CollectionReference<Map<String, dynamic>>? get _notificationsCollection {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  // ===================== INITIALIZATION =====================
  // Call this when app starts
  Future<void> initializePushNotifications() async {
    await _requestPermission(); // ask user permission
    await _saveFcmToken(); // save device token
    _listenForTokenRefresh(); // listen if token changes
  }

  // Ask user for notification permission
  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  // ===================== SAVE TOKEN =====================
  // Save device token in Firestore
  Future<void> _saveFcmToken() async {
    final docRef = _userDoc;
    if (docRef == null) {
      return;
    }

    String? token;

    // Web does not support FCM like mobile
    if (kIsWeb) {
      return;
    } else {
      token = await _messaging.getToken();
    }

    if (token == null) {
      return;
    }

    debugPrint('FCM TOKEN: $token');

    // Save token to Firestore
    await docRef.set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===================== TOKEN REFRESH =====================
  // If token changes → update Firestore
  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) async {
      final docRef = _userDoc;
      if (docRef == null) {
        return;
      }

      debugPrint('FCM TOKEN REFRESHED: $newToken');

      await docRef.set({
        'fcmToken': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // ===================== GET SETTINGS =====================
  Future<NotificationSettingsData> getSettings() async {
    final docRef = _userDoc;

    // Default settings if user not found
    if (docRef == null) {
      return const NotificationSettingsData(
        pushNotifications: true,
        arrivalAlerts: true,
        selectedStop: '',
      );
    }

    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};

    return NotificationSettingsData(
      pushNotifications: data['pushNotifications'] != false,
      arrivalAlerts: data['arrivalAlerts'] != false,
      selectedStop: data['selectedStop']?.toString() ?? '',
    );
  }

  // ===================== SAVE SETTINGS =====================
  Future<void> saveSettings({
    required bool pushNotifications,
    required bool arrivalAlerts,
    required String selectedStop,
  }) async {
    final docRef = _userDoc;
    if (docRef == null) {
      return;
    }

    await docRef.set({
      'pushNotifications': pushNotifications,
      'arrivalAlerts': arrivalAlerts,
      'selectedStop': selectedStop,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===================== GET NOTIFICATIONS =====================
  // Stream for real-time notifications
  Stream<List<UserNotificationItem>> notificationsStream() {
    final collection = _notificationsCollection;

    if (collection == null) {
      return const Stream.empty();
    }

    return collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => UserNotificationItem.fromMap(doc.id, doc.data()),
                  )
                  .toList(),
        );
  }

  // ===================== UNREAD COUNT =====================
  // Returns number of unread notifications
  Stream<int> unreadCountStream() {
    final collection = _notificationsCollection;

    if (collection == null) {
      return Stream.value(0);
    }

    return collection
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ===================== MARK AS READ =====================
  Future<void> markAllAsRead() async {
    final collection = _notificationsCollection;
    if (collection == null) {
      return;
    }

    final snapshot = await collection.where('isRead', isEqualTo: false).get();

    final batch = _firestore.batch();

    // Update all unread → read
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // ===================== DELETE ALL =====================
  Future<void> clearAllNotifications() async {
    final collection = _notificationsCollection;
    if (collection == null) {
      return;
    }

    final snapshot = await collection.get();
    final batch = _firestore.batch();

    // Delete all notifications
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ===================== CREATE NOTIFICATION =====================
  Future<bool> createNotificationIfAllowed({
    required String notificationId,
    required String title,
    required String body,
    required String type,
    required String route,
    required String tripId,
    bool requireArrivalAlerts = false,
  }) async {
    // Get user settings
    final settings = await getSettings();
    final collection = _notificationsCollection;

    if (collection == null) return false;

    // Check if notifications are enabled
    if (!settings.pushNotifications) return false;

    // Check arrival alerts condition
    if (requireArrivalAlerts && !settings.arrivalAlerts) return false;

    // Prevent duplicate notifications
    final existingDoc = await collection.doc(notificationId).get();
    if (existingDoc.exists) {
      return false;
    }

    // Save notification
    await collection.doc(notificationId).set({
      'title': title,
      'body': body,
      'type': type,
      'route': route,
      'tripId': tripId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }
}
