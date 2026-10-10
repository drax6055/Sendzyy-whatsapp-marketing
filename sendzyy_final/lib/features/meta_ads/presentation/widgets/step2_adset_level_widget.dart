import 'package:flutter/material.dart';

class Step2AdSetLevelWidget extends StatelessWidget {
  final TextEditingController adSetNameController;
  final String destinationType;
  final ValueChanged<String> onDestinationChanged;
  final String optimizationGoal;
  final ValueChanged<String> onOptimizationGoalChanged;
  final bool advantageBudgetAtCampaign;
  final String adSetBudgetType;
  final ValueChanged<String> onAdSetBudgetTypeChanged;
  final TextEditingController adSetBudgetAmountController;
  final bool runContinuously;
  final ValueChanged<bool> onRunContinuouslyChanged;
  final String audienceType;
  final ValueChanged<String> onAudienceTypeChanged;
  final int ageMin;
  final int ageMax;
  final ValueChanged<RangeValues> onAgeRangeChanged;
  final String gender;
  final ValueChanged<String> onGenderChanged;
  final List<String> interests;
  final ValueChanged<List<String>> onInterestsChanged;
  final String placementType;
  final ValueChanged<String> onPlacementTypeChanged;
  final List<String> selectedPlatforms;
  final ValueChanged<List<String>> onPlatformsChanged;

  const Step2AdSetLevelWidget({
    super.key,
    required this.adSetNameController,
    required this.destinationType,
    required this.onDestinationChanged,
    required this.optimizationGoal,
    required this.onOptimizationGoalChanged,
    required this.advantageBudgetAtCampaign,
    required this.adSetBudgetType,
    required this.onAdSetBudgetTypeChanged,
    required this.adSetBudgetAmountController,
    required this.runContinuously,
    required this.onRunContinuouslyChanged,
    required this.audienceType,
    required this.onAudienceTypeChanged,
    required this.ageMin,
    required this.ageMax,
    required this.onAgeRangeChanged,
    required this.gender,
    required this.onGenderChanged,
    required this.interests,
    required this.onInterestsChanged,
    required this.placementType,
    required this.onPlacementTypeChanged,
    required this.selectedPlatforms,
    required this.onPlatformsChanged,
  });

  static const List<Map<String, dynamic>> _destinations = [
    {
      'id': 'ON_AD',
      'title': 'Instant Forms',
      'icon': Icons.dynamic_form_rounded,
      'desc': 'Generate leads using native in-app forms with pre-filled fields',
    },
    {
      'id': 'WHATSAPP',
      'title': 'WhatsApp',
      'icon': Icons.chat_rounded,
      'desc': 'Start real-time conversations directly on your WhatsApp number',
    },
    {
      'id': 'WEBSITE',
      'title': 'Website',
      'icon': Icons.language_rounded,
      'desc': 'Send traffic or leads to your landing page or website',
    },
    {
      'id': 'MESSENGER',
      'title': 'Messenger',
      'icon': Icons.send_rounded,
      'desc': 'Drive conversations directly into Facebook Messenger',
    },
    {
      'id': 'PHONE_CALL',
      'title': 'Calls',
      'icon': Icons.phone_in_talk_rounded,
      'desc': 'Encourage people to phone your business directly',
    },
    {
      'id': 'INSTAGRAM_PROFILE',
      'title': 'Instagram Profile',
      'icon': Icons.camera_alt_rounded,
      'desc': 'Drive visits to your Instagram profile and increase followers',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Ad Set Name
          _buildCard(
            title: 'Ad Set Name',
            icon: Icons.layers_rounded,
            child: TextField(
              controller: adSetNameController,
              decoration: const InputDecoration(
                hintText: 'e.g. India - Age 22-45 - Business Owners',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Conversion Destination
          _buildCard(
            title: 'Conversion Destination',
            icon: Icons.near_me_rounded,
            subtitle: 'Choose where you want to send people after they tap your ad.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _destinations.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isNarrow ? 1 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isNarrow ? 2.5 : 1.45,
                  ),
              itemBuilder: (context, index) {
                final dest = _destinations[index];
                final isSelected = destinationType == dest['id'];
                return InkWell(
                  onTap: () => onDestinationChanged(dest['id']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1877F2).withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1877F2) : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              dest['icon'] as IconData,
                              color: isSelected ? const Color(0xFF1877F2) : Colors.grey.shade700,
                              size: 22,
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF1877F2), size: 18),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dest['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? const Color(0xFF1877F2) : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dest['desc'] as String,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  );
                },
              );
            },
          ),
        ),
          const SizedBox(height: 16),

          // Section 3: Performance Goal
          _buildCard(
            title: 'Performance Goal',
            icon: Icons.speed_rounded,
            subtitle: 'Determines what result Meta AI optimizes your ad delivery towards.',
            child: DropdownButtonFormField<String>(
              value: optimizationGoal,
              decoration: const InputDecoration(labelText: 'Optimization Goal'),
              items: const [
                DropdownMenuItem(value: 'LEAD_GENERATION', child: Text('Maximize number of leads')),
                DropdownMenuItem(value: 'QUALITY_LEAD', child: Text('Maximize number of conversion leads')),
                DropdownMenuItem(value: 'LINK_CLICKS', child: Text('Maximize number of link clicks')),
                DropdownMenuItem(value: 'LANDING_PAGE_VIEWS', child: Text('Maximize landing page views')),
                DropdownMenuItem(value: 'CONVERSATIONS', child: Text('Maximize messaging conversations')),
                DropdownMenuItem(value: 'REACH', child: Text('Maximize reach of ads')),
                DropdownMenuItem(value: 'IMPRESSIONS', child: Text('Maximize number of impressions')),
              ],
              onChanged: (val) => onOptimizationGoalChanged(val ?? 'LEAD_GENERATION'),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Budget & Schedule (if not CBO)
          if (!advantageBudgetAtCampaign) ...[
            _buildCard(
              title: 'Budget & Schedule',
              icon: Icons.calendar_today_rounded,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: adSetBudgetType,
                          decoration: const InputDecoration(labelText: 'Budget Type'),
                          items: const [
                            DropdownMenuItem(value: 'daily', child: Text('Daily Budget')),
                            DropdownMenuItem(value: 'lifetime', child: Text('Lifetime Budget')),
                          ],
                          onChanged: (val) => onAdSetBudgetTypeChanged(val ?? 'daily'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: adSetBudgetAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            prefixText: '₹ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Run this ad set continuously', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Ad runs indefinitely until you pause it'),
                    value: runContinuously,
                    activeColor: const Color(0xFF1877F2),
                    onChanged: onRunContinuouslyChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 5: Audience
          _buildCard(
            title: 'Audience Targeting',
            icon: Icons.people_outline_rounded,
            subtitle: 'Define who you want to see your ads across Meta platforms.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audience Type Toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'advantage_plus',
                      label: Text('Advantage+ Audience (AI)'),
                      icon: Icon(Icons.auto_awesome),
                    ),
                    ButtonSegment(
                      value: 'manual',
                      label: Text('Manual Audience'),
                      icon: Icon(Icons.tune),
                    ),
                  ],
                  selected: {audienceType},
                  onSelectionChanged: (set) => onAudienceTypeChanged(set.first),
                ),
                const SizedBox(height: 16),

                // Location info chip
                const Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Color(0xFF1877F2), size: 20),
                      SizedBox(width: 8),
                      Text('India (Country)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Age Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Age Range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$ageMin – $ageMax years', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1877F2))),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(ageMin.toDouble(), ageMax.toDouble()),
                  min: 18,
                  max: 65,
                  divisions: 47,
                  activeColor: const Color(0xFF1877F2),
                  onChanged: onAgeRangeChanged,
                ),
                const SizedBox(height: 12),

                // Gender
                const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildGenderChip('ALL', 'All'),
                    const SizedBox(width: 8),
                    _buildGenderChip('MALE', 'Men'),
                    const SizedBox(width: 8),
                    _buildGenderChip('FEMALE', 'Women'),
                  ],
                ),
                const SizedBox(height: 16),

                // Interests & Behaviors
                const Text('Detailed Targeting (Interests & Industries)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Business & Industry',
                    'Entrepreneurship',
                    'Small Business',
                    'Digital Marketing',
                    'E-commerce',
                    'Real Estate',
                    'Technology',
                    'Healthcare',
                  ].map((preset) {
                    final isAdded = interests.contains(preset);
                    return FilterChip(
                      label: Text(preset),
                      selected: isAdded,
                      selectedColor: const Color(0xFF1877F2).withValues(alpha: 0.15),
                      checkmarkColor: const Color(0xFF1877F2),
                      onSelected: (val) {
                        final updated = List<String>.from(interests);
                        if (val) {
                          updated.add(preset);
                        } else {
                          updated.remove(preset);
                        }
                        onInterestsChanged(updated);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 6: Placements
          _buildCard(
            title: 'Placements',
            icon: Icons.devices_rounded,
            subtitle: 'Choose where your ads are shown across Facebook, Instagram, Messenger, and Audience Network.',
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Advantage+ Placements (Recommended)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Meta AI maximizes your budget by showing ads where they perform best'),
                  value: 'advantage_plus',
                  groupValue: placementType,
                  activeColor: const Color(0xFF1877F2),
                  onChanged: (val) => onPlacementTypeChanged(val!),
                ),
                RadioListTile<String>(
                  title: const Text('Manual Placements', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Choose specific platforms and positions'),
                  value: 'manual',
                  groupValue: placementType,
                  activeColor: const Color(0xFF1877F2),
                  onChanged: (val) => onPlacementTypeChanged(val!),
                ),
                if (placementType == 'manual') ...[
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildPlatformChip('facebook', 'Facebook', Icons.facebook),
                      _buildPlatformChip('instagram', 'Instagram', Icons.camera_alt),
                      _buildPlatformChip('messenger', 'Messenger', Icons.chat),
                      _buildPlatformChip('audience_network', 'Audience Network', Icons.public),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String value, String label) {
    final isSelected = gender == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF1877F2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF1E293B),
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onGenderChanged(value),
    );
  }

  Widget _buildPlatformChip(String platformId, String label, IconData icon) {
    final isSelected = selectedPlatforms.contains(platformId);
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF1877F2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF1E293B),
        fontWeight: FontWeight.w500,
      ),
      onSelected: (val) {
        final updated = List<String>.from(selectedPlatforms);
        if (val) {
          updated.add(platformId);
        } else {
          updated.remove(platformId);
        }
        onPlatformsChanged(updated);
      },
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF1877F2), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
