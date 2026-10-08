import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/meta_campaign_model.dart';
import '../bloc/meta_ads_bloc.dart';
import '../bloc/meta_ads_event.dart';
import '../bloc/meta_ads_state.dart';
import '../widgets/campaign_kpi_card.dart';

class CampaignDetailsAnalyticsPage extends StatelessWidget {
  final MetaCampaignModel campaign;

  const CampaignDetailsAnalyticsPage({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MetaAdsBloc, MetaAdsState>(
      builder: (context, state) {
        // Find updated campaign from state if available
        final currentCampaign = state.campaigns.firstWhere(
          (c) => c.id == campaign.id,
          orElse: () => campaign,
        );
        final insights = currentCampaign.insights;
        final isActive = currentCampaign.status == 'ACTIVE';

        return Scaffold(
          appBar: AppBar(
            title: Text(currentCampaign.name),
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Sync Live Insights from Meta',
                icon: state.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded),
                onPressed: state.isSyncing
                    ? null
                    : () => context.read<MetaAdsBloc>().add(SyncCampaignStatsEvent(currentCampaign.id)),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle_status') {
                    final nextStatus = isActive ? 'PAUSED' : 'ACTIVE';
                    context.read<MetaAdsBloc>().add(UpdateMetaCampaignStatusEvent(currentCampaign.id, nextStatus));
                  } else if (value == 'delete') {
                    _confirmDelete(context, currentCampaign.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Row(
                      children: [
                        Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Pause Campaign' : 'Resume Campaign'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete Campaign', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Status Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentCampaign.status,
                          style: TextStyle(
                            color: isActive ? const Color(0xFF10B981) : Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentCampaign.objective.replaceAll('OUTCOME_', ''),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (currentCampaign.metaCampaignId != null)
                              Text(
                                'Meta ID: ${currentCampaign.metaCampaignId}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final nextStatus = isActive ? 'PAUSED' : 'ACTIVE';
                          context.read<MetaAdsBloc>().add(UpdateMetaCampaignStatusEvent(currentCampaign.id, nextStatus));
                        },
                        icon: Icon(isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                        label: Text(isActive ? 'Pause' : 'Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive ? Colors.grey.shade800 : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(90, 36),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // KPI Metrics Grid
                const Text(
                  'Performance Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    CampaignKpiCard(
                      title: 'Total Spend',
                      value: '₹ ${insights.spend.toStringAsFixed(2)}',
                      icon: Icons.currency_rupee_rounded,
                      iconColor: const Color(0xFF1877F2),
                    ),
                    CampaignKpiCard(
                      title: 'Total Leads',
                      value: '${insights.leadsCount}',
                      icon: Icons.people_alt_rounded,
                      iconColor: const Color(0xFF10B981),
                    ),
                    CampaignKpiCard(
                      title: 'Cost per Lead (CPL)',
                      value: insights.cpl > 0 ? '₹ ${insights.cpl.toStringAsFixed(2)}' : '₹ 0.00',
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                    CampaignKpiCard(
                      title: 'Total Reach',
                      value: '${insights.reach}',
                      icon: Icons.group_work_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                    ),
                    CampaignKpiCard(
                      title: 'Impressions',
                      value: '${insights.impressions}',
                      icon: Icons.visibility_rounded,
                      iconColor: const Color(0xFF06B6D4),
                    ),
                    CampaignKpiCard(
                      title: 'Clicks',
                      value: '${insights.clicks}',
                      subtitle: 'CTR: ${insights.ctr.toStringAsFixed(2)}%',
                      icon: Icons.ads_click_rounded,
                      iconColor: const Color(0xFFEC4899),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Campaign Specs Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Campaign Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      _buildSpecItem('Ad Set Name', currentCampaign.adSetName),
                      _buildSpecItem('Destination', currentCampaign.destinationType),
                      _buildSpecItem('Audience Targeting', 'Ages ${currentCampaign.targeting.ageMin}–${currentCampaign.targeting.ageMax} (${currentCampaign.targeting.gender})'),
                      _buildSpecItem('Optimization Goal', currentCampaign.optimizationGoal),
                      _buildSpecItem('Headline', currentCampaign.creative.headline),
                      _buildSpecItem('Primary Text', currentCampaign.creative.primaryText),
                      _buildSpecItem('Call to Action', currentCampaign.creative.callToAction.replaceAll('_', ' ')),
                      if (currentCampaign.leadForm != null)
                        _buildSpecItem('Lead Form Attached', currentCampaign.leadForm!.formName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String campaignId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign?'),
        content: const Text('This will delete the campaign from Meta Ads and Sendzyy. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MetaAdsBloc>().add(DeleteMetaCampaignEvent(campaignId));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
}
