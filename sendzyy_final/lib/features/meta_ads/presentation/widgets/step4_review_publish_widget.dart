import 'dart:io';
import 'package:flutter/material.dart';

class Step4ReviewPublishWidget extends StatelessWidget {
  final String campaignName;
  final String objective;
  final String budgetDisplay;
  final String adSetName;
  final String destinationType;
  final String audienceDisplay;
  final String primaryText;
  final String headline;
  final String description;
  final String callToAction;
  final String? imagePath;
  final String pageName;
  final bool isLeadFormIncluded;
  final int questionsCount;

  const Step4ReviewPublishWidget({
    super.key,
    required this.campaignName,
    required this.objective,
    required this.budgetDisplay,
    required this.adSetName,
    required this.destinationType,
    required this.audienceDisplay,
    required this.primaryText,
    required this.headline,
    required this.description,
    required this.callToAction,
    required this.imagePath,
    required this.pageName,
    required this.isLeadFormIncluded,
    required this.questionsCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Realistic Facebook Feed Ad Mockup
          const Text(
            'Live Ad Preview (Facebook & Instagram Feed)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Page Avatar, Name, "Sponsored")
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF1877F2),
                        child: const Icon(Icons.business_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pageName.isNotEmpty ? pageName : 'Your Business Page',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Row(
                              children: [
                                Text('Sponsored · ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Icon(Icons.public, size: 12, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_horiz, color: Colors.grey),
                    ],
                  ),
                ),

                // Primary Text
                if (primaryText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(
                      primaryText,
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ),

                // Media / Creative
                if (imagePath != null && File(imagePath!).existsSync())
                  Image.file(
                    File(imagePath!),
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 6),
                        Text('Ad Image Placeholder', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),

                // Headline, Description & CTA Button Bar
                Container(
                  padding: const EdgeInsets.all(14),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'sendzyy.com'.toUpperCase(),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              headline.isNotEmpty ? headline : 'Headline of your offer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: const Color(0xFF1E293B),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(80, 36),
                        ),
                        child: Text(
                          callToAction.replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Campaign Configuration Summary
          _buildCard(
            title: 'Campaign Summary',
            icon: Icons.checklist_rounded,
            child: Column(
              children: [
                _buildSummaryRow('Campaign Name', campaignName),
                _buildSummaryRow('Objective', objective.replaceAll('OUTCOME_', '')),
                _buildSummaryRow('Budget', budgetDisplay),
                _buildSummaryRow('Ad Set Name', adSetName),
                _buildSummaryRow('Destination', destinationType.replaceAll('_', ' ')),
                _buildSummaryRow('Audience', audienceDisplay),
                _buildSummaryRow('Call to Action', callToAction.replaceAll('_', ' ')),
                if (isLeadFormIncluded)
                  _buildSummaryRow('Lead Form', 'Instant Form ($questionsCount questions)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1877F2), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
