import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/group_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/group_selection_dialog.dart';
import 'package:iFloraBuzz/features/messages/data/models/recipient_data.dart';
import 'package:iFloraBuzz/features/messages/presentation/widgets/client_selection_dialog.dart';
import 'package:iFloraBuzz/features/messages/presentation/widgets/phone_contacts_selection_dialog.dart';

/// Reusable recipient picker and manager for WhatsApp Catalog messages.
/// Supports manual phone entry, client database picker, group importer,
/// device contacts selector, and bulk CSV file uploads.
class CatalogRecipientSelector extends StatefulWidget {
  final List<RecipientData> recipients;
  final ValueChanged<List<RecipientData>> onRecipientsChanged;
  final bool isRequired;
  final String label;

  const CatalogRecipientSelector({
    super.key,
    required this.recipients,
    required this.onRecipientsChanged,
    this.isRequired = true,
    this.label = 'Recipient Phone Numbers',
  });

  @override
  State<CatalogRecipientSelector> createState() =>
      CatalogRecipientSelectorState();
}

class CatalogRecipientSelectorState extends State<CatalogRecipientSelector> {
  final TextEditingController _manualCtrl = TextEditingController();
  bool _showCsvUploader = false;
  bool _isUploadingCsv = false;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  /// Flushes any pending text in the manual textfield into the recipients list.
  /// Call this right before validating or sending so typed numbers aren't lost.
  void flushPendingInput() {
    if (_manualCtrl.text.trim().isNotEmpty) {
      _addManualNumbers();
    }
  }

  void _addManualNumbers() {
    final text = _manualCtrl.text.trim();
    if (text.isEmpty) return;

    final existing = widget.recipients.map((r) => r.mobileNumber).toSet();
    final invalid = <String>[];
    final validNumbers = <String>[];

    final entries = text.split(RegExp(r'[,\n\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty);

    for (final entry in entries) {
      final normalized = RecipientData.normalizeNumber(entry);
      if (normalized == null) {
        invalid.add(entry);
      } else if (!existing.contains(normalized) && !validNumbers.contains(normalized)) {
        validNumbers.add(normalized);
      }
    }

    if (invalid.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped invalid number(s): ${invalid.take(3).join(', ')}${invalid.length > 3 ? '...' : ''}. Use 10 digits or 12 digits with 91 prefix.',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (validNumbers.isNotEmpty) {
      final updated = List<RecipientData>.from(widget.recipients)
        ..addAll(validNumbers.map(RecipientData.fromNumber));
      widget.onRecipientsChanged(updated);
      _manualCtrl.clear();
    } else if (invalid.isEmpty && entries.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Number(s) already added to recipients.'),
          duration: Duration(seconds: 2),
        ),
      );
      _manualCtrl.clear();
    }
  }

  Future<void> _addFromClients() async {
    final existingNumbers = widget.recipients.map((r) => r.mobileNumber).toList();
    final selected = await showDialog<List<ClientModel>>(
      context: context,
      builder: (_) => ClientSelectionDialog(existingNumbers: existingNumbers),
    );

    if (selected != null && selected.isNotEmpty) {
      final existingSet = widget.recipients.map((r) => r.mobileNumber).toSet();
      final toAdd = <RecipientData>[];

      for (final client in selected) {
        final normalized = RecipientData.normalizeNumber(client.mobileNumber) ?? client.mobileNumber;
        if (!existingSet.contains(normalized)) {
          existingSet.add(normalized);
          toAdd.add(
            RecipientData(
              mobileNumber: normalized,
              name: client.name.trim().isNotEmpty ? client.name.trim() : null,
              variables: {},
            ),
          );
        }
      }

      if (toAdd.isNotEmpty) {
        final updated = List<RecipientData>.from(widget.recipients)..addAll(toAdd);
        widget.onRecipientsChanged(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${toAdd.length} client(s)')),
          );
        }
      }
    }
  }

  Future<void> _addFromGroup() async {
    final selectedGroup = await showDialog<GroupModel>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => getIt<GroupsBloc>()..add(FetchGroups()),
        child: const GroupSelectionDialog(),
      ),
    );

    if (selectedGroup == null || selectedGroup.clientIds.isEmpty) return;

    try {
      final repo = getIt<ClientRepository>();
      final paginated = await repo.getClients(groupId: selectedGroup.id);
      final clients = paginated.clients;

      final existingSet = widget.recipients.map((r) => r.mobileNumber).toSet();
      final toAdd = <RecipientData>[];

      for (final client in clients) {
        final normalized = RecipientData.normalizeNumber(client.mobileNumber) ?? client.mobileNumber;
        if (!existingSet.contains(normalized)) {
          existingSet.add(normalized);
          toAdd.add(
            RecipientData(
              mobileNumber: normalized,
              name: client.name.trim().isNotEmpty ? client.name.trim() : null,
              variables: {},
            ),
          );
        }
      }

      if (toAdd.isNotEmpty) {
        final updated = List<RecipientData>.from(widget.recipients)..addAll(toAdd);
        widget.onRecipientsChanged(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${toAdd.length} client(s) from group "${selectedGroup.name}"'),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All contacts in this group are already added.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group clients: $e')),
        );
      }
    }
  }

  Future<void> _addFromPhoneContacts() async {
    final existingNumbers = widget.recipients.map((r) => r.mobileNumber).toList();
    final selected = await PhoneContactsSelectionDialog.show(
      context,
      existingNumbers: existingNumbers,
    );

    if (selected != null && selected.isNotEmpty) {
      final existingSet = widget.recipients.map((r) => r.mobileNumber).toSet();
      final toAdd = <RecipientData>[];

      for (final client in selected) {
        final normalized = RecipientData.normalizeNumber(client.mobileNumber) ?? client.mobileNumber;
        if (!existingSet.contains(normalized)) {
          existingSet.add(normalized);
          toAdd.add(
            RecipientData(
              mobileNumber: normalized,
              name: client.name.trim().isNotEmpty && client.name.trim() != 'Phone Contact'
                  ? client.name.trim()
                  : null,
              variables: {},
            ),
          );
        }
      }

      if (toAdd.isNotEmpty) {
        final updated = List<RecipientData>.from(widget.recipients)..addAll(toAdd);
        widget.onRecipientsChanged(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${toAdd.length} phone contact(s)')),
          );
        }
      }
    }
  }

  Future<void> _pickAndParseCsv() async {
    setState(() => _isUploadingCsv = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final rawBytes = file.bytes ??
            (!kIsWeb && file.path != null ? await File(file.path!).readAsBytes() : null);
        if (rawBytes == null) return;

        final content = utf8.decode(rawBytes);
        final List<List<dynamic>> rows = const CsvToListConverter().convert(content);

        // Filter out header row
        final dataRows = rows.where((row) {
          if (row.isEmpty) return false;
          final first = row[0].toString().trim().toLowerCase();
          return first != 'mobile' &&
              first != 'phone' &&
              first != 'number' &&
              first.isNotEmpty;
        }).toList();

        final existing = widget.recipients.map((r) => r.mobileNumber).toSet();
        final List<RecipientData> validList = [];
        int invalidCount = 0;
        int duplicateCount = 0;

        for (final row in dataRows) {
          final rawPhone = row[0].toString().trim();
          final normalized = RecipientData.normalizeNumber(rawPhone);
          if (normalized == null) {
            invalidCount++;
            continue;
          }

          if (existing.contains(normalized)) {
            duplicateCount++;
            continue;
          }

          existing.add(normalized);
          String? name;
          if (row.length > 1 && row[1].toString().trim().isNotEmpty) {
            name = row[1].toString().trim();
          }

          validList.add(
            RecipientData(
              mobileNumber: normalized,
              name: name,
              variables: {},
              fromCsv: true,
            ),
          );
        }

        if (validList.isNotEmpty) {
          final updated = List<RecipientData>.from(widget.recipients)..addAll(validList);
          widget.onRecipientsChanged(updated);
        }

        if (mounted) {
          final summaryParts = <String>[];
          if (validList.isNotEmpty) summaryParts.add('Added ${validList.length} from CSV');
          if (duplicateCount > 0) summaryParts.add('$duplicateCount duplicate(s) skipped');
          if (invalidCount > 0) summaryParts.add('$invalidCount invalid number(s) skipped');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                summaryParts.isNotEmpty
                    ? summaryParts.join(' • ')
                    : 'No valid new numbers found in CSV.',
              ),
              backgroundColor: validList.isNotEmpty ? AppTheme.primaryColor : Colors.orange.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCsv = false);
    }
  }

  void _downloadSampleCsv() async {
    const csvContent =
        'mobile,name\n'
        '919876543210,John Doe\n'
        '919123456789,Jane Smith\n'
        '917890123456,Acme Retail\n';
    await webDownloadBytes(
      utf8.encode(csvContent),
      'sample_catalog_contacts.csv',
      mimeType: 'text/csv',
    );
  }

  void _removeRecipient(String mobileNumber) {
    final updated = widget.recipients.where((r) => r.mobileNumber != mobileNumber).toList();
    widget.onRecipientsChanged(updated);
  }

  void _clearAllRecipients() {
    widget.onRecipientsChanged([]);
    _manualCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final totalRecipients = widget.recipients.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (widget.isRequired)
                      const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: totalRecipients > 0
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        totalRecipients == 1
                            ? '1 Contact'
                            : '$totalRecipients Contacts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: totalRecipients > 0 ? AppTheme.primaryColor : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (totalRecipients > 0)
                TextButton.icon(
                  onPressed: _clearAllRecipients,
                  icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.redAccent),
                  label: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Manual Entry Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addManualNumbers(),
                  decoration: InputDecoration(
                    hintText: 'Enter phone number(s) e.g. 919876543210 (comma/enter to separate)',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addManualNumbers,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: Clients, Group, CSV, Contacts
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _addFromClients,
                icon: const Icon(Icons.people_outline_rounded, size: 16),
                label: const Text('Add from Clients'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addFromGroup,
                icon: const Icon(Icons.group_work_outlined, size: 16),
                label: const Text('Add from Group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickAndParseCsv,
                icon: _isUploadingCsv
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Upload CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(color: Color(0xFFBBF7D0)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (ResponsiveHelper.isMobile(context))
                OutlinedButton.icon(
                  onPressed: _addFromPhoneContacts,
                  icon: const Icon(Icons.contacts_rounded, size: 16),
                  label: const Text('Device Contacts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFFDDD6FE)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _showCsvUploader = !_showCsvUploader),
                icon: Icon(
                  _showCsvUploader ? Icons.expand_less_rounded : Icons.help_outline_rounded,
                  size: 15,
                  color: Colors.grey.shade600,
                ),
                label: Text(
                  _showCsvUploader ? 'Hide CSV Guide' : 'CSV Sample',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),

          // Collapsible CSV dropzone / sample area
          if (_showCsvUploader) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined, color: Color(0xFF16A34A), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk CSV Upload Format',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Column 1: Phone Number (e.g. 919876543210) • Column 2: Name (optional)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _downloadSampleCsv,
                    icon: const Icon(Icons.download_rounded, size: 15, color: Color(0xFF16A34A)),
                    label: const Text(
                      'Download Sample',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Selected Recipients Display
          if (totalRecipients > 0) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Text(
              'Selected ($totalRecipients):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.recipients.map((r) {
                    final hasName = r.name != null && r.name!.trim().isNotEmpty;
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          hasName
                              ? r.name!.trim()[0].toUpperCase()
                              : '#',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      label: Text(
                        hasName
                            ? '${r.name} • ${r.mobileNumber}'
                            : '+${r.mobileNumber}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: const Color(0xFFF9FAFB),
                      side: BorderSide(color: Colors.grey.shade300),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => _removeRecipient(r.mobileNumber),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
