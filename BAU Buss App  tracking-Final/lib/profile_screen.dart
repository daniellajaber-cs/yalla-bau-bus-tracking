import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'help_center_screen.dart';
import 'login_screen.dart';
import 'student_home_screen.dart';
import 'notification_service.dart';

//This is the Student Profile Screen.
//It allows the student to view their information and customize their preferences

//The app loads the student’s name, email, notification settings,
//and selected stop from Firebase Firestore

//The student selects their preferred stop based on the chosen route,
//and this is used for notifications.

//The student can enable or disable push notifications and arrival alerts,
// and these settings are saved using a notification service
//The logout button signs the user out from Firebase and returns to the login screen.

// This screen shows the student's profile, settings, and preferences
class ProfileScreen extends StatefulWidget {
  // The selected route passed from the home screen
  final String selectedRoute;

  const ProfileScreen({super.key, required this.selectedRoute});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Notification service to handle saving settings
  final NotificationService notificationService = NotificationService();

  // Notification settings
  bool pushNotifications = true;
  bool arrivalAlerts = true;
  bool darkMode = false;

  // Loading indicator while fetching data
  bool isLoading = true;

  // User info from Firebase
  String fullName = 'Student';
  String email = '';

  // Currently selected bus stop
  late String selectedStop;

  // Map of routes and their corresponding stops
  final Map<String, List<String>> routeStops = {
    'Beirut to Debbieh': [
      'Beirut',
      'Choueifat',
      'Khaldeh',
      'Damour',
      'Debbieh',
    ],
    'Debbieh to Beirut': [
      'Debbieh',
      'Damour',
      'Khaldeh',
      'Choueifat',
      'Beirut',
    ],
    'Debbieh to Saida': [
      'Debbieh',
      'Damour',
      'Jiyeh',
      'Awali',
      'Sahet El Nejmeh',
    ],
    'Saida to Debbieh': [
      'Sahet El Nejmeh',
      'Awali',
      'Jiyeh',
      'Damour',
      'Debbieh',
    ],
    'Beirut to Saida': [
      'Beirut',
      'Khaldeh',
      'Damour',
      'Awali',
      'Sahet El Nejmeh',
    ],
  };

  // Get stops for the currently selected route
  List<String> get stopsForSelectedRoute =>
      routeStops[widget.selectedRoute] ?? ['No stops'];

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bgColor =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
  Color get cardColor => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get borderColor =>
      isDark ? const Color(0xFF334155) : const Color(0xFFEAECF0);
  Color get titleColor => isDark ? Colors.white : const Color(0xFF101828);
  Color get subColor =>
      isDark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);
  Color get sectionColor =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF98A2B3);
  Color get fieldBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  @override
  // Initialize selected stop and load user data when page opens
  void initState() {
    super.initState();
    selectedStop = stopsForSelectedRoute.first;

    loadUserData();
  }

  // Load student data from Firebase Firestore
  Future<void> loadUserData() async {
    try {
      // Get current logged-in user
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) {
          // Added braces to satisfy the curly-braces lint.
          return;
        }
        setState(() {
          isLoading = false;
        });
        return;
      }

      final userDoc =
          // Get user document from Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data = userDoc.data();

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      // Update UI with user data and settings
      setState(() {
        fullName = data?['fullName']?.toString() ?? 'Student';
        email = data?['email']?.toString() ?? user.email ?? '';
        pushNotifications = data?['pushNotifications'] != false;
        arrivalAlerts = data?['arrivalAlerts'] != false;

        final savedStop = data?['selectedStop']?.toString();
        if (savedStop != null && stopsForSelectedRoute.contains(savedStop)) {
          selectedStop = savedStop;
        }

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile data: $e')),
      );
    }
  }

  // Save notification preferences and selected stop
  Future<void> saveNotificationSettings() async {
    try {
      await notificationService.saveSettings(
        pushNotifications: pushNotifications,
        arrivalAlerts: arrivalAlerts,
        selectedStop: selectedStop,
      );
    } catch (e) {
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save notification settings: $e')),
      );
    }
  }

  // Log out the user and return to login screen
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  String getInitials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();

    if (parts.isEmpty) {
      // Added braces to satisfy the curly-braces lint.
      return 'S';
    }
    if (parts.length == 1) {
      // Added braces to satisfy the curly-braces lint.
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final stops = stopsForSelectedRoute;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const StudentHomeScreen(),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: titleColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 42,
                                  backgroundColor: const Color(0xFF7F9387),
                                  child: Text(
                                    getInitials(fullName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2F80ED),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              fullName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: subColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? const Color(0xFF1D4ED8).withValues(
                                          alpha: 0.15,
                                        ) // Replaced deprecated withOpacity with withValues.
                                        : const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? const Color(0xFF3B82F6).withValues(
                                            alpha: 0.35,
                                          ) // Replaced deprecated withOpacity with withValues.
                                          : const Color(0xFFD7E7FF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(
                                                0xFF1E3A8A,
                                              ).withValues(
                                                alpha: 0.25,
                                              ) // Replaced deprecated withOpacity with withValues.
                                              : const Color(0xFFEAF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_outlined,
                                      color: Color(0xFF2F80ED),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'My Stop',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: fieldBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          dropdownColor: cardColor,
                                          value: selectedStop,
                                          isExpanded: true,
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: subColor,
                                          ),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: titleColor,
                                          ),
                                          items:
                                              stops.map((stop) {
                                                return DropdownMenuItem<String>(
                                                  value: stop,
                                                  child: Text(
                                                    stop,
                                                    style: TextStyle(
                                                      color: titleColor,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                          onChanged: (value) async {
                                            if (value == null) {
                                              // Added braces to satisfy the curly-braces lint.
                                              return;
                                            }
                                            setState(() {
                                              selectedStop = value;
                                            });
                                            await saveNotificationSettings();
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4, top: 8),
                                child: Text(
                                  'Current route: ${widget.selectedRoute}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: subColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _sectionTitle('Notifications & Settings'),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  _settingsTile(
                                    icon: Icons.notifications_active_outlined,
                                    iconBg: const Color(0xFFFFF1E8),
                                    iconColor: const Color(0xFFF79009),
                                    title: 'Push Notifications',
                                    subtitle: 'Receive app notifications',
                                    value: pushNotifications,
                                    onChanged: (value) async {
                                      setState(() {
                                        pushNotifications = value;
                                      });
                                      await saveNotificationSettings();
                                    },
                                  ),
                                  _divider(),
                                  _settingsTile(
                                    icon: Icons.alarm_rounded,
                                    iconBg: const Color(0xFFEAFBF0),
                                    iconColor: const Color(0xFF12B76A),
                                    title: 'Arrival Alerts',
                                    subtitle: 'Notify 5 mins before arrival',
                                    value: arrivalAlerts,
                                    onChanged: (value) async {
                                      setState(() {
                                        arrivalAlerts = value;
                                      });
                                      await saveNotificationSettings();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _sectionTitle('Information'),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.help_outline_rounded,
                                      color: subColor,
                                    ),
                                    title: Text(
                                      'Help Center',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: titleColor,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right_rounded,
                                      color: sectionColor,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const HelpCenterScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _divider(),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.logout_rounded,
                                      color: Color(0xFFF04438),
                                    ),
                                    title: const Text(
                                      'Log Out',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFF04438),
                                      ),
                                    ),
                                    onTap: logout,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Yalla BAU',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w800,
                                color: sectionColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: sectionColor,
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF2F4F7),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: sectionColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF2F80ED),
          ),
        ],
      ),
    );
  }
}
