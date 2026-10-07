import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/meta_ads_bloc.dart';
import '../bloc/meta_ads_event.dart';
import '../bloc/meta_ads_state.dart';

class MetaLeadsPage extends StatefulWidget {
  final String? campaignId;

  const MetaLeadsPage({super.key, this.campaignId});

  @override
  State<MetaLeadsPage> createState() => _MetaLeadsPageState();
}

class _MetaLeadsPageState extends State<MetaLeadsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<MetaAdsBloc>().add(LoadMetaLeadsEvent(campaignId: widget.campaignId));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meta Ads Leads'),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<MetaAdsBloc>().add(LoadMetaLeadsEvent(campaignId: widget.campaignId)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by lead name or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Leads List
          Expanded(
            child: BlocBuilder<MetaAdsBloc, MetaAdsState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredLeads = state.leads.where((lead) {
                  if (_searchQuery.isEmpty) return true;
                  return lead.name.toLowerCase().contains(_searchQuery) ||
                      lead.mobileNumber.contains(_searchQuery) ||
                      lead.email.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredLeads.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.contact_phone_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No leads captured from Meta ads yet'
                              : 'No leads matching "$_searchQuery"',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Leads submitted via your Facebook & Instagram ads will appear here in real-time.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLeads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lead = filteredLeads[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.12),
                            child: const Icon(Icons.person, color: Color(0xFF1877F2)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      lead.name.isNotEmpty ? lead.name : 'Meta Lead',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    if (lead.createdAt != null)
                                      Text(
                                        DateFormat('dd MMM, hh:mm a').format(lead.createdAt!),
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(lead.mobileNumber, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                if (lead.email.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(lead.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                                if (lead.formName.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Form: ${lead.formName}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
