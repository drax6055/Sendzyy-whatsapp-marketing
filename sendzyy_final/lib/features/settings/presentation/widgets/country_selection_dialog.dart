import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/services/country_code_service.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

class CountrySelectionDialog extends StatefulWidget {
  final String currentIso;
  final Future<void> Function(String iso, String name, String dialCode) onSelected;

  const CountrySelectionDialog({
    super.key,
    required this.currentIso,
    required this.onSelected,
  });

  @override
  State<CountrySelectionDialog> createState() => _CountrySelectionDialogState();
}

class _CountrySelectionDialogState extends State<CountrySelectionDialog> {
  final _searchCtrl = TextEditingController();
  String _filter = '';
  bool _isSaving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isMobile = screenWidth < 600;

    final all = CountryCodeService.allCountries;
    final filtered = _filter.isEmpty
        ? all
        : all.where((c) {
            final q = _filter.toLowerCase();
            return (c['name']?.toLowerCase().contains(q) ?? false) ||
                (c['dialCode']?.contains(q) ?? false) ||
                (c['iso']?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.94 : 480.0,
          maxHeight: isMobile ? (screenHeight * 0.82).clamp(360.0, 600.0) : 600.0,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.public, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Select Default Country Code',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Numbers without a country code will automatically have this country code added.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by country name, dial code, or ISO (e.g. India, 91, IN)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _filter = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (val) => setState(() => _filter = val.trim()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching countries found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final country = filtered[index];
                              final iso = country['iso'] ?? '';
                              final name = country['name'] ?? '';
                              final dial = country['dialCode'] ?? '';
                              final flag = country['flag'] ?? '🌐';
                              final isSelected =
                                  iso.toUpperCase() == widget.currentIso.toUpperCase();

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                leading: Text(
                                  flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '+$dial',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      )
                                    : const SizedBox(width: 20),
                                onTap: () async {
                                  setState(() => _isSaving = true);
                                  Navigator.of(context).pop();
                                  await widget.onSelected(iso, name, dial);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

