// Imports main Flutter UI widgets
import 'dart:developer'
    as developer; // Added developer logging for avoid_print lint.
import 'package:flutter/material.dart';

//  Firebase Authentication (used to create/login users)
import 'package:firebase_auth/firebase_auth.dart';

//  Firestore database (used to store user data)
import 'package:cloud_firestore/cloud_firestore.dart';

// Register screen (stateful because UI changes like loading)
class RegisterScreen extends StatefulWidget {
  //  Variable to know if user is student or driver
  final bool isStudent;

  // Constructor (requires isStudent value)
  const RegisterScreen({super.key, required this.isStudent});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// State of RegisterScreen
class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers to get input from text fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  //  Controller for confirm password field
  final TextEditingController confirmPasswordController =
      TextEditingController();

  //  Loading flag (true when creating account)
  bool isLoading = false;

  //  Password visibility (show/hide password)
  bool isPasswordVisible = false;

  //  Confirm password visibility
  bool isConfirmPasswordVisible = false;

  //  Dispose controllers when screen is destroyed (important for memory)
  @override
  void dispose() {
    nameController.dispose(); // free memory
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  //  Check if email matches BAU format
  bool isValidBauEmail(String email) {
    // Clean email (remove spaces + lowercase)
    final cleanEmail = email.trim().toLowerCase();

    // If student → must end with student email
    if (widget.isStudent) {
      return cleanEmail.endsWith('@student.bau.edu.lb');
    } else {
      // If driver → must end with driver email
      return cleanEmail.endsWith('@driver.bau.edu.lb');
    }
  }

  //  Function to create account
  Future<void> createAccount() async {
    // Get values from text fields
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    //  Check if any field is empty
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      // Show error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    //  Check email format (student/driver)
    if (!isValidBauEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isStudent
                ? 'Student email must end with @student.bau.edu.lb'
                : 'Driver email must end with @driver.bau.edu.lb',
          ),
        ),
      );
      return;
    }

    //  Check if passwords match
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    //  Check password length
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    // Start loading
    setState(() {
      isLoading = true;
    });

    try {
      developer.log(
        'CREATE ACCOUNT STARTED',
      ); // Replaced print with developer.log.

      //  Create user in Firebase Authentication
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      developer.log(
        'AUTH ACCOUNT CREATED',
      ); // Replaced print with developer.log.

      // Get user ID from Firebase
      final uid = userCredential.user!.uid;

      //  Save user data in Firestore database
      await FirebaseFirestore.instance
          .collection('users') // collection name
          .doc(uid) // document ID = user ID
          .set({
            'uid': uid, // user id
            'fullName': name, // user name
            'email': email, // user email
            'role': widget.isStudent ? 'student' : 'driver', // role
            'createdAt': FieldValue.serverTimestamp(), // time from server
          });

      developer.log(
        'FIRESTORE DATA SAVED',
      ); // Replaced print with developer.log.

      // Check if widget is still active
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully')),
      );

      // Go back to previous screen (login)
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // Firebase-specific errors

      developer.log(
        'REGISTER ERROR CODE: ${e.code}',
      ); // Replaced print with developer.log.
      developer.log(
        'REGISTER ERROR MESSAGE: ${e.message}',
      ); // Replaced print with developer.log.

      String message = 'Firebase error: ${e.code}';

      // Handle common Firebase errors
      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Email/Password sign-in is not enabled in Firebase';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error, check your internet connection';
      }

      // Show error message
      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      //  Any other error

      developer.log('GENERAL ERROR: $e'); // Replaced print with developer.log.

      if (!mounted) {
        // Added braces to satisfy the curly-braces lint.
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('General error: $e')));
    } finally {
      //  Stop loading
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color
      backgroundColor: Colors.grey[100],

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // Allows keyboard to close when dragging
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

              child: ConstrainedBox(
                // Makes content at least full screen height
                constraints: BoxConstraints(minHeight: constraints.maxHeight),

                child: IntrinsicHeight(
                  child: Padding(
                    // Screen padding
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        //  Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),

                            // Go back when pressed
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        //  App logo
                        Image.asset('assets/BAUbuslogo.png', width: 100),

                        const SizedBox(height: 20),

                        //  Title
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        //  Subtitle
                        const Text(
                          'Join the BAU Bus Tracker community',
                          style: TextStyle(color: Colors.grey),
                        ),

                        const SizedBox(height: 30),

                        //  Full name field
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Full Name',
                            prefixIcon: const Icon(Icons.person),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        //  Email field
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            hintText: 'BAU Email',
                            prefixIcon: const Icon(Icons.email),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        //  Password field with eye toggle
                        TextField(
                          controller: passwordController,

                          // Hide/show password
                          obscureText: !isPasswordVisible,

                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: const Icon(Icons.lock),

                            // Eye icon button
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),

                              // Toggle visibility
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                            ),

                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        //  Confirm password field
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: !isConfirmPasswordVisible,

                          decoration: InputDecoration(
                            hintText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),

                            suffixIcon: IconButton(
                              icon: Icon(
                                isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),

                              onPressed: () {
                                setState(() {
                                  isConfirmPasswordVisible =
                                      !isConfirmPasswordVisible;
                                });
                              },
                            ),

                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        //  Create account button
                        SizedBox(
                          width: double.infinity,
                          height: 50,

                          child: ElevatedButton(
                            // Disable button if loading
                            onPressed: isLoading ? null : createAccount,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),

                            // Show loading or text
                            child:
                                isLoading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      'Create Account',
                                      style: TextStyle(fontSize: 18),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        //  Back to login text
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Already have an account? Back to Login',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),

                        const SizedBox(height: 20),
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
