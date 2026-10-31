import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import '../../data/models/instagram_publish_models.dart';
import '../../data/repositories/instagram_publish_repository.dart';
import 'package:iFloraBuzz/core/di/injection.dart';

class InstagramPostDetailsDialog extends StatefulWidget {
  final InstagramPostModel post;
  final VoidCallback onUpdated;

  const InstagramPostDetailsDialog({
    super.key,
    required this.post,
    required this.onUpdated,
  });

  @override
  State<InstagramPostDetailsDialog> createState() => _InstagramPostDetailsDialogState();
}

class _InstagramPostDetailsDialogState extends State<InstagramPostDetailsDialog> {
  final InstagramPublishRepository _repository = getIt<InstagramPublishRepository>();
  bool _isLoading = false;
  late InstagramPostModel _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.green.shade600;
      case 'scheduled':
        return Colors.amber.shade800;
      case 'publishing':
        return Colors.blue.shade600;
      case 'failed':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Icons.check_circle_rounded;
      case 'scheduled':
        return Icons.access_time_rounded;
      case 'publishing':
        return Icons.sync_rounded;
      case 'failed':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Scheduled Post?'),
        content: const Text('Are you sure you want to cancel and delete this scheduled Instagram post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Post'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel & Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await _repository.deletePost(_post.id);
      if (mounted) {
        if (success) {
          widget.onUpdated();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scheduled post cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to cancel post'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRetry() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repository.retryPost(_post.id);
      if (mounted) {
        setState(() => _post = updated);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully on retry!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retry failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_post.status);
    final statusIcon = _getStatusIcon(_post.status);
    final mediaCount = _post.mediaUrls.length;
    final firstMedia = _post.mediaUrls.isNotEmpty ? _post.mediaUrls.first : '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Status Badge, Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _post.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _post.mediaType == 'CAROUSEL'
                        ? 'CAROUSEL ($mediaCount)'
                        : _post.mediaType,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ratio ${_post.aspectRatio}',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  splashRadius: 20,
                ),
              ],
            ),
            const Divider(height: 24),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Preview
                    if (firstMedia.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 280),
                          width: double.infinity,
                          color: Colors.black12,
                          child: _post.mediaType == 'REEL'
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      color: Colors.black87,
                                      height: 200,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.movie_rounded, color: Colors.white, size: 48),
                                            SizedBox(height: 8),
                                            Text('Instagram Reel Video', style: TextStyle(color: Colors.white70)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: FaIcon(FontAwesomeIcons.instagram, color: Colors.white, size: 20),
                                    ),
                                  ],
                                )
                              : Image.network(
                                  firstMedia,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 180,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: Icon(Icons.image_not_supported_rounded, color: Colors.grey.shade500, size: 40),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Timestamp Info
                    if (_post.status == 'scheduled' && _post.scheduledAt != null)
                      _buildInfoRow(
                        Icons.schedule_rounded,
                        'Scheduled for',
                        DateFormat('EEEE, MMM d, y • h:mm a').format(_post.scheduledAt!),
                        color: Colors.amber.shade900,
                      ),
                    if (_post.status == 'published' && _post.publishedAt != null)
                      _buildInfoRow(
                        Icons.check_circle_outline_rounded,
                        'Published on',
                        DateFormat('EEEE, MMM d, y • h:mm a').format(_post.publishedAt!),
                        color: Colors.green.shade800,
                      ),
                    if (_post.location.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'Location',
                        _post.location,
                      ),
                    if (_post.userTags.isNotEmpty)
                      _buildInfoRow(
                        Icons.person_pin_circle_outlined,
                        'Tagged Users',
                        _post.userTags.map((t) => '@${t.username}').join(', '),
                      ),

                    const SizedBox(height: 12),

                    // Caption
                    if (_post.caption.isNotEmpty) ...[
                      const Text(
                        'Caption:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _post.caption,
                          style: const TextStyle(fontSize: 13.5, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Hashtags
                    if (_post.hashtags.isNotEmpty) ...[
                      const Text(
                        'Hashtags:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _post.hashtags.map((tag) {
                          final label = tag.startsWith('#') ? tag : '#$tag';
                          return Chip(
                            label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF00376B))),
                            backgroundColor: Colors.blue.shade50,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Error Message (if failed)
                    if (_post.status == 'failed' && _post.errorMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _post.errorMessage,
                                style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 24),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_post.status == 'scheduled' || _post.status == 'failed') ...[
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete Post'),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_post.status == 'failed') ...[
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry Publishing'),
                  ),
                  const SizedBox(width: 12),
                ],
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color ?? Colors.grey.shade800,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

