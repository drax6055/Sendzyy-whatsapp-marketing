import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = [
    {
      'q': 'What is Sendzyy?',
      'a':
          'Sendzyy is an all-in-one WhatsApp Business API marketing, broadcast, and automation platform that helps businesses launch broadcasts, automate chatbot flows, manage contacts, and track analytics.',
    },
    {
      'q': 'How do I send a Broadcast campaign?',
      'a':
          'Navigate to "Broadcast" in the sidebar, select an approved Meta message template, select target client groups or custom contacts, and click Send. You can also schedule broadcasts for future delivery.',
    },
    {
      'q': 'Where do I view Scheduled Campaigns and Reports?',
      'a':
          'Expand the "Reports" parent menu in the sidebar to access:\n• Campaign Reports: Detailed logs for message delivery, read rates, and failures.\n• Meta Analytics: Visual metrics for overall message volume and performance.\n• Scheduled: Manage queued campaigns scheduled for future automated delivery.',
    },
    {
      'q': 'How do I switch active WhatsApp Phone Numbers?',
      'a':
          'Click the active phone selector dropdown in the top header (or go to Settings -> General Settings). For account security, you will be prompted to verify your login password before switching numbers.',
    },
    {
      'q': 'How do I edit my WhatsApp Business Profile?',
      'a':
          'Click your avatar in the top-right menu and select "WhatsApp Business Profile" (or navigate to Settings -> General Settings). Click the Edit icon button on the top right to update your profile image, status text, description, address, email, vertical category, and up to 2 website links.',
    },
    {
      'q': 'How does the Retry System work?',
      'a':
          'Under Settings -> Retry System, Sendzyy tracks failed message dispatches and automatically re-attempts delivery or allows manual single/bulk retries to maximize delivery rates.',
    },
    {
      'q': 'How do I build and configure Chatbot Flows?',
      'a':
          'Go to "Chatbot" in the sidebar. You can create visual flow trees using drag-and-drop nodes such as Start, Send Message, Quick Reply, Interactive Buttons, Media, User Input, and End node.',
    },
    {
      'q': 'How do I manage Clients and Contact Groups?',
      'a':
          'Go to "Clients" in the sidebar. You can manually add contacts, bulk import/export clients via Excel/CSV, and organize contacts into custom target groups for segmented broadcasting.',
    },
    {
      'q': 'How does Lead Management work in Sendzyy?',
      'a':
          'Go to "Leads" in the sidebar to capture, track, and convert incoming leads. Assign lead statuses (New, Contacted, Qualified, Converted, Lost), add tags, and record activity notes.',
    },
    {
      'q': 'Why can\'t I send a free-text message to a client?',
      'a':
          'WhatsApp policy permits free-text conversation replies within a 24-hour window from the client\'s last message. Outside of this 24-hour window, you must initiate conversation using a Meta-approved template.',
    },
    {
      'q': 'What do the chat message ticks (single tick, double tick, blue ticks) mean?',
      'a':
          'In Chats and Campaign Reports, message status ticks represent real-time delivery stages:\n• Single Grey Tick (Sent): Message sent from Sendzyy to Meta WhatsApp servers.\n• Double Grey Ticks (Delivered): Message delivered to the recipient\'s phone.\n• Double Blue Ticks (Read): Recipient has opened and read your message.\n• Red Warning (Failed): Delivery failed (e.g. invalid number, insufficient credits, or Meta policy restriction).',
    },
    {
      'q': 'What do the phone number quality rating badges (GREEN, YELLOW, RED) mean?',
      'a':
          'In the header & settings phone selector dropdown, Meta assigns quality rating badges:\n• GREEN (High Quality): High quality rating with low customer block/report rates.\n• YELLOW (Medium Quality): Medium rating. Consider reviewing broadcast relevance or frequency.\n• RED (Low Quality): Low rating caused by high customer block/report rates. Messaging limits may apply.\n• UNKNOWN: Quality rating is under initial evaluation by Meta.',
    },
    {
      'q': 'What does the Green vs Grey indicator dot in Chats mean?',
      'a':
          'In the Chats conversation list:\n• Green Dot: Active 24-Hour Window. The client messaged recently, so you can send free-text messages and custom replies.\n• Grey Dot: Expired 24-Hour Window. Free-text messaging is locked; send a Meta-approved template to re-engage the client.',
    },
    {
      'q': 'How do I set up Integrations and Webhooks?',
      'a':
          'Expand Settings -> Integrations in the sidebar to configure integrations for E-Commerce platforms (Shopify, WooCommerce, WordPress) and webhooks for real-time message automation.',
    },
    {
      'q': 'How do I update API Configuration credentials?',
      'a':
          'If your Meta credentials change, click the gear (Settings) icon in the top header bar to update your WhatsApp Business Account ID, Phone Number ID, and Access Token.',
    },
    {
      'q': 'How are Invalid Numbers calculated in Campaign Summary?',
      'a':
          'When you upload a CSV or enter manual numbers in Broadcast, each number is validated through CountryCodeService phone normalization:\n\n'
          '• Valid: Must be a valid E.164 number between 7 and 15 digits (with country code or local format).\n'
          '• Invalid:\n'
          '  - Contains letters or symbols ("N/A", "none", "1234abc").\n'
          '  - Too short (e.g. fewer than 6 digits).\n'
          '  - Exceeds the ITU international limit of 15 digits.\n\n'
          'Every number that cannot be normalized is skipped and adds +1 to Invalid Numbers (displayed in red if > 0 in the Campaign Summary).',
    },
    {
      'q': 'How are Duplicate Numbers calculated in Campaign Summary?',
      'a':
          'Because numbers from different countries have different formats (some with +, some with country code, some with spaces/dashes), Sendzyy performs Canonical International Deduplication:\n\n'
          '1. Format Normalization Before Comparison:\n'
          '   Every number is first converted to clean international digits.\n'
          '   Example: +1 (212) 555-0100 and 12125550100 both normalize to 12125550100 (USA). Sendzyy recognizes that Row 1 and Row 8 are the exact same recipient; the second row is skipped and counted as +1 Duplicate.\n\n'
          '2. Local vs Full Format Deduplication:\n'
          '   A local number 9876543210 (India local) and full number 919876543210 both normalize to 919876543210. Recognized as the same contact and skipped as +1 Duplicate.\n\n'
          '3. No False Collisions Between Different Countries:\n'
          '   A USA number 19876543210 and an Indian number 919876543210 have different country codes (1 vs 91). They are correctly treated as two distinct, unique recipients.',
    },
    {
      'q': 'Can I send messages to multiple countries in a single CSV?',
      'a':
          'Yes! You can upload a single CSV with numbers from any mix of countries (e.g. USA, Australia, UK, UAE, India, etc.). Simply ensure international numbers include their country code (e.g. +1... or 1..., +61..., +44...). Any numbers entered without a country code will automatically receive your tenant\'s Default Country Code configured in Settings.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 20 : 32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: AppTheme.secondaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help & Q/A',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Frequently asked questions & support',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // FAQ Section
          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...(_faqs.map((faq) => _FaqTile(q: faq['q']!, a: faq['a']!))),

          const SizedBox(height: 40),

          // Contact Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 16 : 28),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Still need help? Contact Us',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _ContactRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: 'iflorainfopvtltd@gmail.com',
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: '+91 90997 05065',
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.language_outlined,
                  label: 'Website',
                  value: 'www.iflorainfo.com',
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.access_time_outlined,
                  label: 'Support Hours',
                  value: 'Mon – Sat, 9:00 AM – 6:00 PM IST',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;

  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'Q',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Text(
          q,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.secondaryColor,
          ),
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
