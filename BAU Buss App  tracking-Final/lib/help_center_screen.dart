// Import Flutter UI package
import 'package:flutter/material.dart';

// Import url_launcher to open WhatsApp link
import 'package:url_launcher/url_launcher.dart';

// Stateless widget because this screen does not change dynamically
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  // ===================== OPEN WHATSAPP =====================
  // This function opens WhatsApp when user taps the contact number
  Future<void> openWhatsApp() async {
    // Create WhatsApp URL with predefined message
    final Uri url = Uri.parse(
      'https://wa.me/96176991274?text=Hello%20I%20need%20help%20with%20Yalla%20BAU',
    );

    // Check if device can open the URL
    if (await canLaunchUrl(url)) {
      // Open WhatsApp externally (not inside app)
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ===================== FAQ ITEM BUILDER =====================
  // This function builds each FAQ box (question + answer)
  Widget buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // space between FAQ items
      padding: const EdgeInsets.all(14), // inner spacing
      decoration: BoxDecoration(
        color: Colors.white, // background color
        borderRadius: BorderRadius.circular(14), // rounded corners
        border: Border.all(color: const Color(0xFFEAECF0)), // border color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // align left
        children: [
          // Question text
          Text(
            question,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700, // bold
              color: Color(0xFF101828),
            ),
          ),

          const SizedBox(height: 8), // space between question & answer
          // Answer text
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5, // line spacing
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== UI BUILD =====================
  @override
  Widget build(BuildContext context) {
    // Colors used in UI (for consistency)
    const Color bgColor = Color(0xFFF5F7FB); // background
    const Color cardColor = Colors.white; // cards
    const Color borderColor = Color(0xFFEAECF0);
    const Color titleColor = Color(0xFF101828);
    const Color subColor = Color(0xFF667085);
    const Color blueColor = Color(0xFF2F80ED);

    return Scaffold(
      backgroundColor: bgColor, // page background
      // ===================== APP BAR =====================
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0, // no shadow
        centerTitle: true,

        // Back arrow color
        iconTheme: const IconThemeData(color: titleColor),

        // Title text
        title: const Text(
          'Help Center',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),

      // ===================== BODY =====================
      body: SingleChildScrollView(
        // allows scrolling
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===================== ABOUT CARD =====================
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
                  // Row: Icon + Title
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFEAF2FF),

                        // Bus icon
                        child: Icon(
                          Icons.directions_bus_rounded,
                          color: blueColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),

                      // Title
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

                  // Description text
                  Text(
                    'Yalla BAU is a smart bus tracking application designed to help students follow their bus in real time and stay informed about its progress...',
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

            // ===================== FAQ TITLE =====================
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),

            const SizedBox(height: 12),

            // ===================== FAQ ITEMS =====================
            buildFaqItem(
              'How does bus tracking work?',
              'The app shows the current location of the bus based on real-time updates provided during the trip.',
            ),

            buildFaqItem(
              'When will I receive notifications?',
              'You will receive notifications when the bus is near your selected stop and when it reaches your stop...',
            ),

            buildFaqItem(
              'How do I choose my stop?',
              'You can select your stop from the Profile page based on your current route.',
            ),

            buildFaqItem(
              'What should I do if I do not receive notifications?',
              'Make sure notifications are enabled in your profile settings...',
            ),

            const SizedBox(height: 8),

            // ===================== CONTACT CARD =====================
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
                  // Title
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Description
                  const Text(
                    'For any inquiries or problems, please contact this number:',
                    style: TextStyle(fontSize: 13.5, color: subColor),
                  ),

                  const SizedBox(height: 12),

                  // Clickable phone number
                  InkWell(
                    onTap: openWhatsApp, // open WhatsApp when tapped
                    child: const Row(
                      children: [
                        Icon(Icons.phone, color: Color(0xFF25D366)),
                        SizedBox(width: 8),

                        // Phone number text
                        Text(
                          '+961 76 991 274',
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
