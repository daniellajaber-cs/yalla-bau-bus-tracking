import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'driver_help_center_screen.dart';
import 'login_screen.dart';

//It also includes notification settings, such as push notifications, arrival alerts,
//and trip status updates.
//The driver can open the Help Center from this page or log out of the account

// This page shows the driver's profile information and settings
class DriverProfilePage extends StatefulWidget {
  final String busId; //Bus ID received from the Driver Dashboard

  const DriverProfilePage({super.key, required this.busId});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

// Notification setting values controlled by switches
class _DriverProfilePageState extends State<DriverProfilePage> {
  bool pushNotifications = true;
  bool arrivalAlerts = true;
  bool tripStatusUpdates = false;

  // Driver information loaded from Firebase
  String fullName = '';
  String email = '';
  bool isLoading = true;

  // Load driver data when the page opens
  @override
  void initState() {
    super.initState();
    loadDriverData();
  }

  // This function gets the current driver's data
  //from Firebase Authentication and Firestore
  Future<void> loadDriverData() async {
    try {
      // Get the currently logged-in Firebase user
      final user = FirebaseAuth.instance.currentUser;

      // If no user is logged in, show default values
      if (user == null) {
        setState(() {
          fullName = 'Unknown Driver';
          email = 'No email found';
          isLoading = false;
        });
        return;
      }

      final uid = user.uid;

      // Get driver document from the users collection using the user ID
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      // If the driver exists in Firestore, load name and email
      if (userDoc.exists) {
        final data = userDoc.data()!;

        setState(() {
          fullName = data['fullName'] ?? 'Unknown Driver';
          email = data['email'] ?? user.email ?? 'No email found';
          isLoading = false;
        });
      } else {
        setState(() {
          fullName = 'Unknown Driver';
          email = user.email ?? 'No email found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        fullName = 'Unknown Driver';
        email = 'No email found';
        isLoading = false;
      });
    }
  }

  // This function logs out the driver and returns to the login screen
  Future<void> logout() async {
    try {
      // Sign out from Firebase Authentication
      await FirebaseAuth.instance.signOut();

      // Clear saved login data but keep onboarding as already seen
      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool('seenOnboarding') ?? true;
      await prefs.clear();
      await prefs.setBool('seenOnboarding', seenOnboarding);

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }
      // Remove all previous screens and open the login screen
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        leading: TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Back',
            style: TextStyle(color: Colors.blue, fontSize: 14),
          ),
        ),
        leadingWidth: 70,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // PROFILE TOP
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              const CircleAvatar(
                                radius: 38,
                                backgroundColor: Color(0xFFBFC7BE),
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bus ID: ${widget.busId.isEmpty ? "---" : widget.busId}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // SETTINGS TITLE
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // SETTINGS CARD
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFFFE7C2),
                              child: Icon(
                                Icons.notifications,
                                size: 16,
                                color: Colors.orange,
                              ),
                            ),
                            title: const Text(
                              'Push Notifications',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            value: pushNotifications,
                            activeThumbColor: Colors.blue,
                            onChanged: (value) {
                              setState(() {
                                pushNotifications = value;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFDDF5E3),
                              child: Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.green,
                              ),
                            ),
                            title: const Text(
                              'Arrival Alerts',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Text(
                              'Notify when bus reaches a stop',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: arrivalAlerts,
                            activeThumbColor: Colors.blue,
                            onChanged: (value) {
                              setState(() {
                                arrivalAlerts = value;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFE7D9FF),
                              child: Icon(
                                Icons.directions_bus,
                                size: 16,
                                color: Colors.purple,
                              ),
                            ),
                            title: const Text(
                              'Trip Status Updates',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Text(
                              'Notify for trip activity changes',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: tripStatusUpdates,
                            activeThumbColor: Colors.blue,
                            onChanged: (value) {
                              setState(() {
                                tripStatusUpdates = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // INFORMATION TITLE
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'INFORMATION',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // INFORMATION CARD
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFEAF2FF),
                              child: Icon(
                                Icons.help_outline,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                            title: const Text(
                              'Help Center',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const DriverHelpCenterScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFFFEAEA),
                              child: Icon(
                                Icons.logout,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                            title: const Text(
                              'Log Out',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                            onTap: logout,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'BAU BUS TRACKER\nVERSION 2.4',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
    );
  }
}
