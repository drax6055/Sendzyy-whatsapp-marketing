import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import '../../data/models/instagram_publish_models.dart';
import '../../data/repositories/instagram_publish_repository.dart';
import 'instagram_profile_setup_page.dart';
import '../widgets/instagram_publish_dialog.dart';
import '../widgets/instagram_post_details_dialog.dart';

class InstagramPublishPage extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;

  const InstagramPublishPage({
    super.key,
    this.onNavigateToProfile,
  });

  @override
  State<InstagramPublishPage> createState() => _InstagramPublishPageState();
}

class _InstagramPublishPageState extends State<InstagramPublishPage> {
  final InstagramPublishRepository _repository = getIt<InstagramPublishRepository>();

  bool _isLoading = true;
  bool _isConnected = false;
  String _username = '';
  String? _errorMessage;

  // Calendar State
  late DateTime _currentDisplayMonth; // First day of displayed month
  late DateTime _minMonth; // Current month
  late DateTime _maxMonth; // 2 years ahead from current month

  List<InstagramPostModel> _posts = [];
  bool _isPostsLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minMonth = DateTime(now.year, now.month, 1);
    _maxMonth = DateTime(now.year + 2, now.month, 1);
    _currentDisplayMonth = _minMonth;

    _checkConnectionAndLoadData();
  }

  Future<void> _checkConnectionAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _repository.getProfile();
      final connected = profile['connected'] == true;
      final username = profile['username']?.toString() ?? '';

      setState(() {
        _isConnected = connected;
        _username = username;
        _isLoading = false;
      });

      if (connected) {
        await _fetchMonthPosts();
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _fetchMonthPosts() async {
    setState(() => _isPostsLoading = true);
    try {
      final posts = await _repository.getPosts(
        year: _currentDisplayMonth.year,
        month: _currentDisplayMonth.month,
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _isPostsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPostsLoading = false);
      }
    }
  }

  void _goToPreviousMonth() {
    final prev = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month - 1, 1);
    if (!prev.isBefore(_minMonth)) {
      setState(() => _currentDisplayMonth = prev);
      _fetchMonthPosts();
    }
  }

  void _goToNextMonth() {
    final next = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month + 1, 1);
    if (!next.isAfter(_maxMonth)) {
      setState(() => _currentDisplayMonth = next);
      _fetchMonthPosts();
    }
  }

  void _goToToday() {
    setState(() => _currentDisplayMonth = _minMonth);
    _fetchMonthPosts();
  }

  void _redirectToProfile() {
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InstagramProfileSetupPage()),
      );
    }
  }

  void _openPublishDialog({DateTime? targetDate}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InstagramPublishDialog(
        accountUsername: _username,
        initialDate: targetDate,
        onSuccess: (post) {
          _fetchMonthPosts();
        },
      ),
    );
  }

  void _openPostDetails(InstagramPostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => InstagramPostDetailsDialog(
        post: post,
        onUpdated: () => _fetchMonthPosts(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isConnected) {
      return _buildNotConnectedView();
    }

    return _buildPublishCalendarView();
  }

  // ── 1. Disconnected State View ───────────────────────────────────────────────
  Widget _buildNotConnectedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBar(showPublishButton: false),
          const SizedBox(height: 36),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF007F).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.instagram,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Instagram Account Not Connected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Connect your Instagram Business or Creator account to start scheduling Single Photos, Carousels, and Reels directly from Sendzyy with interactive preview and content calendar.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _redirectToProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE1306C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.link_rounded, size: 20),
                    label: const Text(
                      'Connect Now',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Connected Calendar View ───────────────────────────────────────────────
  Widget _buildPublishCalendarView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Left Instagram Icon + Title, Top Right Publish New Content
          _buildHeaderBar(showPublishButton: true),
          const SizedBox(height: 24),

          // Month / Year Navigation & Filters Bar (up to 2 years ahead)
          _buildCalendarControlsBar(),
          const SizedBox(height: 16),

          // Monthly Calendar Grid
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  // ── Header Bar ─────────────────────────────────────────────────────────────
  Widget _buildHeaderBar({required bool showPublishButton}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF007F).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const FaIcon(
            FontAwesomeIcons.instagram,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Instagram Publish',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                ),
                if (_username.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1306C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE1306C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.instagram, size: 12, color: Color(0xFFE1306C)),
                        const SizedBox(width: 5),
                        Text(
                          '@$_username',
                          style: const TextStyle(
                            color: Color(0xFFE1306C),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Schedule, preview, and publish Photos, Carousels, and Reels to your Instagram feed',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        if (showPublishButton)
          ElevatedButton.icon(
            onPressed: () => _openPublishDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Publish New Content',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
      ],
    );
  }

  // ── Month / Year Navigation & Filters Bar ──────────────────────────────────
  Widget _buildCalendarControlsBar() {
    final canGoPrev = !_currentDisplayMonth.isBefore(_minMonth) &&
        !(_currentDisplayMonth.year == _minMonth.year && _currentDisplayMonth.month == _minMonth.month);
    final canGoNext = _currentDisplayMonth.isBefore(_maxMonth);

    final scheduledCount = _posts.where((p) => p.status == 'scheduled').length;
    final publishedCount = _posts.where((p) => p.status == 'published').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Previous Month button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: canGoPrev ? _goToPreviousMonth : null,
            tooltip: 'Previous Month',
            splashRadius: 20,
          ),
          const SizedBox(width: 8),

          // Month Dropdown
          DropdownButton<int>(
            value: _currentDisplayMonth.month,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            items: List.generate(12, (index) {
              final monthNum = index + 1;
              final monthName = DateFormat('MMMM').format(DateTime(2026, monthNum, 1));
              return DropdownMenuItem(
                value: monthNum,
                child: Text(monthName),
              );
            }),
            onChanged: (newMonth) {
              if (newMonth != null) {
                final target = DateTime(_currentDisplayMonth.year, newMonth, 1);
                if (!target.isBefore(_minMonth) && !target.isAfter(_maxMonth)) {
                  setState(() => _currentDisplayMonth = target);
                  _fetchMonthPosts();
                }
              }
            },
          ),
          const SizedBox(width: 10),

          // Year Dropdown (Allows up to 2 years ahead!)
          DropdownButton<int>(
            value: _currentDisplayMonth.year,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor),
            items: List.generate(3, (index) {
              final year = _minMonth.year + index;
              return DropdownMenuItem(
                value: year,
                child: Text('$year'),
              );
            }),
            onChanged: (newYear) {
              if (newYear != null) {
                final target = DateTime(newYear, _currentDisplayMonth.month, 1);
                if (!target.isBefore(_minMonth) && !target.isAfter(_maxMonth)) {
                  setState(() => _currentDisplayMonth = target);
                  _fetchMonthPosts();
                }
              }
            },
          ),

          const SizedBox(width: 12),
          // Today button
          OutlinedButton(
            onPressed: _goToToday,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Today', style: TextStyle(fontSize: 12.5)),
          ),

          const SizedBox(width: 8),
          // Next Month button
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: canGoNext ? _goToNextMonth : null,
            tooltip: 'Next Month (Up to 2 years ahead)',
            splashRadius: 20,
          ),

          const Spacer(),

          // Stats Chips
          if (_isPostsLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            _buildStatusSummaryBadge(
              icon: Icons.schedule_rounded,
              color: Colors.amber.shade800,
              label: '$scheduledCount Scheduled',
            ),
            const SizedBox(width: 12),
            _buildStatusSummaryBadge(
              icon: Icons.check_circle_rounded,
              color: Colors.green.shade700,
              label: '$publishedCount Published',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusSummaryBadge({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Monthly Calendar Grid ──────────────────────────────────────────────────
  Widget _buildCalendarGrid() {
    final year = _currentDisplayMonth.year;
    final month = _currentDisplayMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Sunday is 0 offset
    final startWeekdayOffset = firstDayOfMonth.weekday % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Days of week header row
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: weekDays.map((day) {
                final isWeekend = day == 'Sun' || day == 'Sat';
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isWeekend ? Colors.red.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Calendar Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 weeks fixed grid for visual uniformity
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final dayIndex = index - startWeekdayOffset + 1;

              // Empty leading or trailing cells
              if (dayIndex < 1 || dayIndex > daysInMonth) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.grey.shade100, width: 0.5),
                  ),
                );
              }

              final cellDate = DateTime(year, month, dayIndex);
              final isPast = cellDate.isBefore(today);
              final isToday = cellDate.year == today.year && cellDate.month == today.month && cellDate.day == today.day;

              // Find posts on this date
              final dayPosts = _posts.where((post) {
                if (post.scheduledAt != null) {
                  final s = post.scheduledAt!;
                  return s.year == year && s.month == month && s.day == dayIndex;
                }
                if (post.publishedAt != null) {
                  final p = post.publishedAt!;
                  return p.year == year && p.month == month && p.day == dayIndex;
                }
                return false;
              }).toList();

              return _buildCalendarDateCell(
                date: cellDate,
                dayNumber: dayIndex,
                isPast: isPast,
                isToday: isToday,
                posts: dayPosts,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Individual Date Cell ───────────────────────────────────────────────────
  Widget _buildCalendarDateCell({
    required DateTime date,
    required int dayNumber,
    required bool isPast,
    required bool isToday,
    required List<InstagramPostModel> posts,
  }) {
    return InkWell(
      // Prevent scheduling for past dates
      onTap: isPast
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot schedule or publish content for past dates'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : () => _openPublishDialog(targetDate: date),
      child: Container(
        decoration: BoxDecoration(
          color: isPast
              ? Colors.grey.shade50
              : isToday
                  ? AppTheme.primaryColor.withValues(alpha: 0.04)
                  : Colors.white,
          border: Border.all(
            color: isToday ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isToday ? 1.5 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Day Number Row
            Row(
              children: [
                if (isToday)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$dayNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPast ? Colors.grey.shade400 : Colors.grey.shade800,
                    ),
                  ),
                const Spacer(),
                if (!isPast && posts.isEmpty)
                  Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Posts Cards in Date Box (or empty blank)
            Expanded(
              child: posts.isEmpty
                  ? const SizedBox.shrink() // keep empty dates blank
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, pIndex) {
                        final post = posts[pIndex];
                        return _buildPostCoverThumbnail(post);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Small Cover Image / Post Card in Date Box ─────────────────────────────
  Widget _buildPostCoverThumbnail(InstagramPostModel post) {
    final hasMedia = post.mediaUrls.isNotEmpty;
    final coverUrl = hasMedia ? post.mediaUrls.first : '';
    final isPublished = post.status == 'published';
    final isFailed = post.status == 'failed';
    final isReel = post.mediaType == 'REEL';
    final isCarousel = post.mediaType == 'CAROUSEL';

    Color badgeColor = Colors.amber.shade800;
    if (isPublished) badgeColor = Colors.green.shade700;
    if (isFailed) badgeColor = Colors.red.shade700;

    String timeLabel = '';
    if (post.status == 'scheduled' && post.scheduledAt != null) {
      timeLabel = DateFormat('h:mm a').format(post.scheduledAt!);
    } else if (post.publishedAt != null) {
      timeLabel = DateFormat('h:mm a').format(post.publishedAt!);
    }

    return InkWell(
      onTap: () => _openPostDetails(post),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            // Thumbnail Image
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 34,
                height: 34,
                color: Colors.black12,
                child: coverUrl.isNotEmpty
                    ? (isReel
                        ? Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Icon(Icons.movie_rounded, color: Colors.white, size: 16),
                            ),
                          )
                        : Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16),
                          ))
                    : const Icon(Icons.image, size: 16),
              ),
            ),
            const SizedBox(width: 6),
            // Status and media indicator
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (isReel)
                        const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(Icons.movie_rounded, size: 10, color: Colors.grey),
                        )
                      else if (isCarousel)
                        const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(Icons.view_carousel_rounded, size: 10, color: Colors.grey),
                        ),
                      Expanded(
                        child: Text(
                          isPublished
                              ? 'Published'
                              : isFailed
                                  ? 'Failed'
                                  : timeLabel.isNotEmpty
                                      ? timeLabel
                                      : 'Scheduled',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (post.caption.isNotEmpty)
                    Text(
                      post.caption,
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
