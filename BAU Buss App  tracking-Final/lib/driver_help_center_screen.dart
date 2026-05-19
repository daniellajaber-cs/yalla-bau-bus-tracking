import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Package used to open external links such as WhatsApp

//The page also includes a contact support section. When the driver presses
//the phone number,
// the app opens WhatsApp with a prepared message using the url_launcher package.

// This screen shows help information and support options for drivers
class DriverHelpCenterScreen extends StatelessWidget {
  const DriverHelpCenterScreen({super.key});

  // This function opens WhatsApp with a prepared help message
  Future<void> openWhatsApp() async {
    // WhatsApp link with phone number and default message
    final Uri url = Uri.parse(
      'https://wa.me/96176056681?text=Hello%20I%20need%20help%20with%20Yalla%20BAU%20Driver',
    );

    // Open WhatsApp outside the app

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // This reusable widget creates one FAQ card
  Widget buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFF5F7FB);
    const Color cardColor = Colors.white;
    const Color borderColor = Color(0xFFEAECF0);
    const Color titleColor = Color(0xFF101828);
    const Color subColor = Color(0xFF667085);
    const Color blueColor = Color(0xFF2F80ED);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: titleColor),
        title: const Text(
          'Help Center',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFEAF2FF),
                        child: Icon(
                          Icons.directions_bus_rounded,
                          color: blueColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'About Yalla BAU',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Yalla BAU is a smart bus tracking application designed to help students follow their bus in real time and stay informed about its progress. The app allows you to select your route and stop, receive notifications when the bus is near or has arrived, and view live updates throughout the trip. Our goal is to make your daily commute easier, more reliable, and stress-free.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            buildFaqItem(
              'How do I start a trip?',
              'Press the "Start Trip" button before leaving. This activates live tracking for students.',
            ),
            buildFaqItem(
              'What happens when I mark the bus as full?',
              'Students will immediately receive a "Bus is full" alert and will not be able to rely on this bus.',
            ),
            buildFaqItem(
              'How do I end the trip?',
              'Press "End Trip" when you reach the final destination. This stops tracking for all students.',
            ),
            buildFaqItem(
              'Can I change passenger count during the trip?',
              'Yes, you can update the passenger count anytime using the controls.',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'For any inquiries or problems, please contact this number:',
                    style: TextStyle(fontSize: 13.5, color: subColor),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: openWhatsApp,
                    child: const Row(
                      children: [
                        Icon(Icons.phone, color: Color(0xFF25D366)),
                        SizedBox(width: 8),
                        Text(
                          '+961 76 056 681',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF25D366),
                            decoration: TextDecoration.underline,
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
    );
  }
}
