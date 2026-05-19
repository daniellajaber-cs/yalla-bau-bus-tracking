import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';

//The main.dart file controls the app startup flow, initializes Firebase,
//and manages the onboarding logic before navigating the user to the login system

void main() async {
  // Ensure Flutter is initialized before using async code
  WidgetsFlutterBinding.ensureInitialized();

  //Initialize Firebase differently for web and mobile
  if (kIsWeb) {
    // Firebase configuration for web platform
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBoKLk94Nw2D2qj_93pFqBtlWDPaoqhBPY",
        authDomain: "yalla-bau.firebaseapp.com",
        projectId: "yalla-bau",
        storageBucket: "yalla-bau.firebasestorage.app",
        messagingSenderId: "896268056395",
        appId: "1:896268056395:web:d35fedbae34ea56e1e1ace",
        measurementId: "G-21QTGZDX4H",
      ),
    );
  } else {
    // Default Firebase initialization for mobile
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Check if user has already seen onboarding screens
  Future<bool> checkOnboarding() async {
    // Get stored value from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seenOnboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // Decide which screen to show based on onboarding status
      home: FutureBuilder<bool>(
        future: checkOnboarding(),
        builder: (context, snapshot) {
          // Show loading spinner while checking data

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If error occurs, go to login screen
          if (snapshot.hasError) {
            return const LoginScreen();
          }

          // If onboarding seen → go to login
          // If not → show onboarding screens

          final seen = snapshot.data ?? false;
          return seen ? const LoginScreen() : const OnboardingScreen();
        },
      ),
    );
  }
}

// Model class representing one onboarding page
class OnboardingItem {
  final String image;
  final Color backgroundColor;
  final BoxFit fit;

  const OnboardingItem({
    required this.image,
    required this.backgroundColor,
    required this.fit,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Controller to swipe between onboarding pages

  final PageController _controller = PageController();
  int currentPage = 0;

  final List<OnboardingItem> pages = const [
    OnboardingItem(
      image: 'assets/opening.jpg',
      backgroundColor: Color(0xFF179EF3),
      fit: BoxFit.cover,
    ),
    OnboardingItem(
      image: 'assets/mobileopening.png',
      backgroundColor: Color(0xFF4A4FB3),
      fit: BoxFit.contain,
    ),
    OnboardingItem(
      image: 'assets/map.png',
      backgroundColor: Color(0xFF9ED8E9),
      fit: BoxFit.contain,
    ),
    OnboardingItem(
      image: 'assets/phone.png',
      backgroundColor: Color(0xFFA7CD6E),
      fit: BoxFit.contain,
    ),
  ];

  void finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget buildFirstPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: const Color(0xFF179EF3),
                child: Image.asset(
                  'assets/opening.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: h * 0.08,
                color: const Color(0xFF179EF3),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildNormalPage(OnboardingItem item) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: item.backgroundColor,
      child: Image.asset(
        item.image,
        fit: item.fit,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget buildPage(int index) {
    if (index == 0) {
      // Added braces to satisfy the curly-braces lint.
      return buildFirstPage();
    }
    return buildNormalPage(pages[index]);
  }

  Widget buildDot(int index) {
    final isActive = currentPage == index;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: isActive ? 10 : 8,
      height: isActive ? 10 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white54,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isLastPage = currentPage == pages.length - 1;

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (index) {
                setState(() {
                  currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return buildPage(index);
              },
            ),
            if (currentPage == 0)
              Positioned(
                bottom: 70,
                right: 20,
                child: Row(
                  children: const [
                    Text(
                      "Swipe to get started!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            Positioned(
              left: size.width * 0.06,
              right: size.width * 0.06,
              bottom: size.height * 0.02,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: List.generate(
                        pages.length,
                        (index) => buildDot(index),
                      ),
                    ),
                    if (currentPage == 0) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Copyright © 2026 Click Round Technologies',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                    if (isLastPage) ...[
                      SizedBox(height: size.height * 0.02),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: finishOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1546A0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Yalla!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
