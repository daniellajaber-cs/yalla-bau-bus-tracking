import 'dart:developer'
    as developer; // Added developer logging for avoid_print lint.
import 'package:flutter/material.dart';
import 'student_home_screen.dart';
import 'driver_dashboard_page.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

//This page is the Login Screen. It allows the user to choose whether they are logging in as a student or a driver.

//The system checks that the email belongs to the correct BAU domain.
//Student emails must end with student.bau.edu.lb, and driver emails must end with driver.bau.edu.lb.

//After that, Firebase Authentication checks the email and password.
//Then Firestore is used to check the saved role of the user. If the role matches, the app opens either the Student Home Screen or the Driver Dashboard.

// This screen allows students and drivers to log in
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isStudent =
      true; // Controls whether the selected login type is Student or Driver
  bool isLoading = false; // Shows loading while Firebase is checking login
  bool isPasswordVisible = false; // Controls password visibility

  // Controllers used to read email and password input
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // This function runs when the page is removed from memory.
  // We dispose the controllers to avoid memory leaks.
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Check if the email matches the selected user type
  bool isValidBauEmail(String email) {
    final cleanEmail = email.trim().toLowerCase();

    if (isStudent) {
      return cleanEmail.endsWith('@student.bau.edu.lb');
    } else {
      return cleanEmail.endsWith('@driver.bau.edu.lb');
    }
  }

  // This function logs the user in using Firebase Authentication
  Future<void> signIn() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    // Check if the email belongs to the selected BAU role
    if (!isValidBauEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isStudent
                ? 'Student email must end with @student.bau.edu.lb'
                : 'Driver email must end with @driver.bau.edu.lb',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Sign in user using Firebase email and password

      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        if (!mounted) {
          // Added braces to satisfy the curly-braces lint.
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found in database')),
        );

        await FirebaseAuth.instance.signOut();
        return;
      }

      final userData = userDoc.data()!;
      final savedRole = userData['role'];
      final selectedRole = isStudent ? 'student' : 'driver';

      if (savedRole != selectedRole) {
        if (!mounted) {
          // Added braces to satisfy the curly-braces lint.
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This account is registered as ${savedRole == 'student' ? 'Student' : 'Driver'}',
            ),
          ),
        );

        await FirebaseAuth.instance.signOut();
        return;
      }

      await NotificationService().initializePushNotifications();

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login successful')));

      // Navigate depending on the user's saved role.
      // Driver goes to DriverDashboardPage.
      // Student goes to StudentHomeScreen.

      if (savedRole == 'driver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DriverDashboardPage()),
        );
      } else if (savedRole == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      developer.log('LOGIN ERROR CODE: ${e.code}');
      developer.log('LOGIN ERROR MESSAGE: ${e.message}');
      String message = 'Something went wrong';

      // Change the message depending on the Firebase error code.
      if (e.code == 'user-not-found') {
        message = 'No user found for this email';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Wrong email or password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Email/Password sign-in is not enabled in Firebase';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error, check your internet connection';
      } else {
        message = 'Firebase error: ${e.code}';
      }

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  //This function runs when the user presses "Forgot Password?"
  //
  // Steps:
  // 1. Read the email from the email field.
  // 2. Check if it is empty.
  // 3. Check if it matches the selected BAU email type.
  // 4. Ask Firebase to send a password reset email.

  Future<void> resetPassword() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email first')));
      return;
    }

    if (!isValidBauEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isStudent
                ? 'Student email must end with @student.bau.edu.lb'
                : 'Driver email must end with @driver.bau.edu.lb',
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Could not send reset email';

      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email';
      } else if (e.code == 'user-not-found') {
        message = 'No user found for this email';
      }

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  //The screen contains:
  // - Logo
  // - App title
  // - Student / Driver selection buttons
  // - Email TextField
  // - Password TextField
  // - Forgot Password button
  // - Login button
  // - Register link

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Image.asset('assets/BAUbuslogo.png', width: 120),
                        const SizedBox(height: 20),
                        const Text(
                          'YALLA BAU!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 3, 23, 39),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Login to continue',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 30),

                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isStudent = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isStudent ? Colors.blue : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Student',
                                      style: TextStyle(
                                        color:
                                            isStudent
                                                ? Colors.white
                                                : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isStudent = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        !isStudent ? Colors.blue : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Driver',
                                      style: TextStyle(
                                        color:
                                            !isStudent
                                                ? Colors.white
                                                : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: !isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: resetPassword,
                            child: const Text('Forgot Password?'),
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child:
                                isLoading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => RegisterScreen(
                                          isStudent: isStudent,
                                        ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
