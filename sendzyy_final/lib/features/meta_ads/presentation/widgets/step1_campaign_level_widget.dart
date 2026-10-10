import 'package:flutter/material.dart';

class Step1CampaignLevelWidget extends StatelessWidget {
  final TextEditingController nameController;
  final String selectedObjective;
  final ValueChanged<String> onObjectiveChanged;
  final List<String> specialAdCategories;
  final ValueChanged<List<String>> onSpecialCategoriesChanged;
  final bool advantageBudget;
  final ValueChanged<bool> onAdvantageBudgetChanged;
  final String budgetType;
  final ValueChanged<String> onBudgetTypeChanged;
  final TextEditingController budgetAmountController;
  final String bidStrategy;
  final ValueChanged<String> onBidStrategyChanged;
  final bool isAbTest;
  final ValueChanged<bool> onAbTestChanged;

  const Step1CampaignLevelWidget({
    super.key,
    required this.nameController,
    required this.selectedObjective,
    required this.onObjectiveChanged,
    required this.specialAdCategories,
    required this.onSpecialCategoriesChanged,
    required this.advantageBudget,
    required this.onAdvantageBudgetChanged,
    required this.budgetType,
    required this.onBudgetTypeChanged,
    required this.budgetAmountController,
    required this.bidStrategy,
    required this.onBidStrategyChanged,
    required this.isAbTest,
    required this.onAbTestChanged,
  });

  static const List<Map<String, dynamic>> _objectives = [
    {
      'id': 'OUTCOME_LEADS',
      'title': 'Leads',
      'icon': Icons.contact_phone_rounded,
      'color': Color(0xFF10B981),
      'description': 'Collect leads for your business via Instant Forms, WhatsApp, Messenger, or phone calls.',
      'goodFor': 'Instant forms, WhatsApp leads, Calls',
    },
    {
      'id': 'OUTCOME_TRAFFIC',
      'title': 'Traffic',
      'icon': Icons.open_in_new_rounded,
      'color': Color(0xFF3B82F6),
      'description': 'Send people to a destination such as your website, landing page, app, or WhatsApp.',
      'goodFor': 'Link clicks, Landing page views',
    },
    {
      'id': 'OUTCOME_ENGAGEMENT',
      'title': 'Engagement',
      'icon': Icons.thumb_up_alt_rounded,
      'color': Color(0xFFF59E0B),
      'description': 'Get more messages, video views, post interactions, Page likes, or event responses.',
      'goodFor': 'Messenger, Instagram, WhatsApp, Video views',
    },
    {
      'id': 'OUTCOME_AWARENESS',
      'title': 'Awareness',
      'icon': Icons.campaign_rounded,
      'color': Color(0xFF8B5CF6),
      'description': 'Show your ads to people who are most likely to remember them and maximize reach.',
      'goodFor': 'Reach, Brand awareness, Video views',
    },
    {
      'id': 'OUTCOME_SALES',
      'title': 'Sales',
      'icon': Icons.shopping_bag_rounded,
      'color': Color(0xFFEF4444),
      'description': 'Find people likely to purchase your goods or services via website, catalog, or WhatsApp.',
      'goodFor': 'Conversions, Catalog sales',
    },
    {
      'id': 'OUTCOME_APP_PROMOTION',
      'title': 'App Promotion',
      'icon': Icons.system_update_rounded,
      'color': Color(0xFF06B6D4),
      'description': 'Find new people to install your app and continue using it.',
      'goodFor': 'App installs, App events',
    },
  ];

  static const List<Map<String, String>> _specialCategoriesList = [
    {'id': 'NONE', 'label': 'No Special Category'},
    {'id': 'HOUSING', 'label': 'Housing (Sale, rental, mortgage)'},
    {'id': 'EMPLOYMENT', 'label': 'Employment (Job offers, internships)'},
    {'id': 'CREDIT', 'label': 'Credit (Credit cards, auto loans, personal loans)'},
    {'id': 'FINANCIAL_PRODUCTS_SERVICES', 'label': 'Financial Products & Services'},
    {'id': 'SOCIAL_ISSUES_ELECTIONS_POLITICS', 'label': 'Social Issues, Elections or Politics'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Campaign Name
          _buildCard(
            title: 'Campaign Details',
            icon: Icons.edit_note_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaign Name *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Summer Leads Promo - WhatsApp Retargeting',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Special Ad Categories
          _buildCard(
            title: 'Special Ad Categories',
            icon: Icons.shield_outlined,
            subtitle:
                'Declare if your ads relate to credit, employment, housing, or social issues to comply with Meta advertising policies.',
            child: Column(
              children: _specialCategoriesList.map((cat) {
                final isSelected = specialAdCategories.contains(cat['id']);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    cat['label']!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  value: isSelected,
                  activeColor: const Color(0xFF1877F2),
                  onChanged: (val) {
                    final updated = List<String>.from(specialAdCategories);
                    if (cat['id'] == 'NONE') {
                      onSpecialCategoriesChanged(['NONE']);
                    } else {
                      updated.remove('NONE');
                      if (val == true) {
                        updated.add(cat['id']!);
                      } else {
                        updated.remove(cat['id']);
                        if (updated.isEmpty) updated.add('NONE');
                      }
                      onSpecialCategoriesChanged(updated);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Campaign Objective (ODAX - 6 Options)
          _buildCard(
            title: 'Campaign Objective (ODAX)',
            icon: Icons.track_changes_rounded,
            subtitle: 'Choose an objective. Meta will optimize delivery to get the most results for your goal.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _objectives.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isNarrow ? 1 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isNarrow ? 1.9 : 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final obj = _objectives[index];
                    final isSelected = selectedObjective == obj['id'];
                    return InkWell(
                      onTap: () => onObjectiveChanged(obj['id']),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? (obj['color'] as Color).withValues(alpha: 0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? (obj['color'] as Color) : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (obj['color'] as Color).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(obj['icon'] as IconData, color: obj['color'] as Color, size: 20),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: obj['color'] as Color, size: 20),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              obj['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isSelected ? (obj['color'] as Color) : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              obj['description'] as String,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.2),
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

          // Section 4: Advantage+ Campaign Budget
          _buildCard(
            title: 'Advantage+ Campaign Budget',
            icon: Icons.auto_awesome_rounded,
            subtitle:
                'Advantage+ campaign budget will distribute your budget across ad sets to get the most results.',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Advantage+ Campaign Budget (CBO)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Set budget at campaign level instead of individual ad sets',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: advantageBudget,
                  activeColor: const Color(0xFF1877F2),
                  onChanged: onAdvantageBudgetChanged,
                ),
                if (advantageBudget) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: budgetType,
                          decoration: const InputDecoration(labelText: 'Budget Type'),
                          items: const [
                            DropdownMenuItem(value: 'daily', child: Text('Daily Budget')),
                            DropdownMenuItem(value: 'lifetime', child: Text('Lifetime Budget')),
                          ],
                          onChanged: (val) => onBudgetTypeChanged(val ?? 'daily'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: budgetAmountController,
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
                  DropdownButtonFormField<String>(
                    value: bidStrategy,
                    decoration: const InputDecoration(labelText: 'Campaign Bid Strategy'),
                    items: const [
                      DropdownMenuItem(
                        value: 'LOWEST_COST_WITHOUT_CAP',
                        child: Text('Highest volume (Lowest Cost)'),
                      ),
                      DropdownMenuItem(
                        value: 'COST_CAP',
                        child: Text('Cost per result goal (Cost Cap)'),
                      ),
                      DropdownMenuItem(
                        value: 'LOWEST_COST_WITH_BID_CAP',
                        child: Text('Bid cap'),
                      ),
                    ],
                    onChanged: (val) => onBidStrategyChanged(val ?? 'LOWEST_COST_WITHOUT_CAP'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 5: A/B Test
          _buildCard(
            title: 'A/B Test Experiment',
            icon: Icons.science_outlined,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Create A/B Test',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Test different creatives, audiences, or placements against each other to see what performs best.',
                style: TextStyle(fontSize: 12),
              ),
              value: isAbTest,
              activeColor: const Color(0xFF1877F2),
              onChanged: onAbTestChanged,
            ),
          ),
        ],
      ),
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
