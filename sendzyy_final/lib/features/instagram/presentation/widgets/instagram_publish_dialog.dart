import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import '../../data/models/instagram_publish_models.dart';
import '../../data/repositories/instagram_publish_repository.dart';

class InstagramPublishDialog extends StatefulWidget {
  final String accountUsername;
  final DateTime? initialDate;
  final Function(InstagramPostModel post) onSuccess;

  const InstagramPublishDialog({
    super.key,
    required this.accountUsername,
    this.initialDate,
    required this.onSuccess,
  });

  @override
  State<InstagramPublishDialog> createState() => _InstagramPublishDialogState();
}

class _InstagramPublishDialogState extends State<InstagramPublishDialog> {
  final InstagramPublishRepository _repository = getIt<InstagramPublishRepository>();

  int _currentStep = 1; // 1 = Media & Format, 2 = Content & Schedule

  // Step 1: Media & Format state
  String _mediaType = 'IMAGE'; // 'IMAGE' | 'CAROUSEL' | 'REEL'
  String _aspectRatio = '4:5'; // '4:5' | '1:1' | '1.91:1' | '9:16'
  final List<PickedMediaFile> _pickedFiles = [];
  int _carouselPreviewIndex = 0;

  // Step 2: Content & Schedule state
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagInputController = TextEditingController();
  final TextEditingController _tagInputController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final List<String> _hashtags = [];
  final List<InstagramUserTag> _userTags = [];

  bool _isScheduled = false;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isSubmitting = false;
  String? _submitError;
  String _submitProgressText = '';

  final List<String> _suggestedHashtags = [
    'marketing',
    'business',
    'growth',
    'entrepreneur',
    'instagram',
    'trending',
    'reels',
    'ecommerce',
    'contentcreator',
    'brand',
  ];

  final List<String> _quickEmojis = ['🔥', '✨', '🚀', '❤️', '👏', '💡', '📸', '🎉'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialDate != null && !widget.initialDate!.isBefore(DateTime(now.year, now.month, now.day))) {
      _selectedDate = widget.initialDate!;
      _isScheduled = true;
    } else {
      _selectedDate = now;
    }

    // Default time 1 hour ahead
    final nextHour = now.add(const Duration(hours: 1));
    _selectedTime = TimeOfDay(hour: nextHour.hour, minute: nextHour.minute);

    _captionController.addListener(() => setState(() {}));
    _locationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagInputController.dispose();
    _tagInputController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onMediaTypeChanged(String type) {
    setState(() {
      _mediaType = type;
      _pickedFiles.clear();
      _carouselPreviewIndex = 0;
      if (type == 'REEL') {
        _aspectRatio = '9:16';
      } else {
        _aspectRatio = '4:5';
      }
    });
  }

  double _getAspectRatioValue() {
    switch (_aspectRatio) {
      case '4:5':
        return 4.0 / 5.0; // 0.8
      case '1:1':
        return 1.0;
      case '1.91:1':
        return 1.91;
      case '9:16':
        return 9.0 / 16.0; // 0.5625
      default:
        return 1.0;
    }
  }

  Future<void> _pickFiles() async {
    try {
      final isVideo = _mediaType == 'REEL';
      final isCarousel = _mediaType == 'CAROUSEL';

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: isVideo ? FileType.video : FileType.image,
        allowMultiple: isCarousel,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          if (isCarousel) {
            for (final file in result.files) {
              if (file.bytes != null && _pickedFiles.length < 10) {
                _pickedFiles.add(
                  PickedMediaFile(
                    name: file.name,
                    bytes: file.bytes!,
                    size: file.size,
                    mimeType: 'image/${file.extension ?? "jpeg"}',
                    isVideo: false,
                  ),
                );
              }
            }
          } else {
            final file = result.files.first;
            if (file.bytes != null) {
              _pickedFiles.clear();
              _pickedFiles.add(
                PickedMediaFile(
                  name: file.name,
                  bytes: file.bytes!,
                  size: file.size,
                  mimeType: isVideo ? 'video/${file.extension ?? "mp4"}' : 'image/${file.extension ?? "jpeg"}',
                  isVideo: isVideo,
                ),
              );
            }
          }
          _carouselPreviewIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting media: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
      if (_carouselPreviewIndex >= _pickedFiles.length) {
        _carouselPreviewIndex = (_pickedFiles.length - 1).clamp(0, 9);
      }
    });
  }

  bool _isStep1Valid() {
    if (_mediaType == 'IMAGE') {
      return _pickedFiles.length == 1 && !_pickedFiles.first.isVideo;
    } else if (_mediaType == 'CAROUSEL') {
      return _pickedFiles.length >= 2 && _pickedFiles.length <= 10;
    } else if (_mediaType == 'REEL') {
      return _pickedFiles.length == 1 && _pickedFiles.first.isVideo;
    }
    return false;
  }

  void _addHashtag(String tag) {
    final clean = tag.trim().replaceAll('#', '').toLowerCase();
    if (clean.isNotEmpty && !_hashtags.contains(clean) && _hashtags.length < 30) {
      setState(() {
        _hashtags.add(clean);
        _hashtagInputController.clear();
      });
    }
  }

  void _removeHashtag(String tag) {
    setState(() {
      _hashtags.remove(tag);
    });
  }

  void _addTag(String username) {
    final clean = username.trim().replaceAll('@', '');
    if (clean.isNotEmpty && !_userTags.any((t) => t.username.toLowerCase() == clean.toLowerCase())) {
      setState(() {
        _userTags.add(InstagramUserTag(username: clean));
        _tagInputController.clear();
      });
    }
  }

  void _removeTag(String username) {
    setState(() {
      _userTags.removeWhere((t) => t.username == username);
    });
  }

  DateTime _computeScheduledDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _submitPost() async {
    final now = DateTime.now();

    if (_isScheduled) {
      final scheduledDateTime = _computeScheduledDateTime();
      if (scheduledDateTime.isBefore(now.add(const Duration(minutes: 2)))) {
        setState(() {
          _submitError = 'Scheduled time must be at least 2 minutes in the future';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
      _submitProgressText = 'Uploading media files to cloud storage...';
    });

    try {
      // 1. Upload files
      final mediaUrls = await _repository.uploadMediaFiles(_pickedFiles);
      if (mediaUrls.isEmpty) {
        throw Exception('Failed to upload media files');
      }

      setState(() {
        _submitProgressText = _isScheduled
            ? 'Scheduling your post...'
            : 'Creating Instagram container & publishing...';
      });

      // 2. Create post
      final scheduledAt = _isScheduled ? _computeScheduledDateTime() : null;
      final post = await _repository.createPost(
        mediaType: _mediaType,
        aspectRatio: _aspectRatio,
        mediaUrls: mediaUrls,
        caption: _captionController.text.trim(),
        hashtags: _hashtags,
        userTags: _userTags,
        location: _locationController.text.trim(),
        isScheduled: _isScheduled,
        scheduledAt: scheduledAt,
      );

      if (mounted) {
        widget.onSuccess(post);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isScheduled
                  ? '🎉 Post scheduled successfully!'
                  : '🎉 Content published successfully to Instagram!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(500.0, 1100.0);
    final dialogHeight = (MediaQuery.of(context).size.height * 0.9).clamp(600.0, 850.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildDialogHeader(),
            const SizedBox(height: 16),
            _buildStepperHeader(),
            const Divider(height: 24),
            Expanded(
              child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ),
            const Divider(height: 24),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const FaIcon(FontAwesomeIcons.instagram, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Publish New Content',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
            ),
            if (widget.accountUsername.isNotEmpty)
              Text(
                'Publishing as @${widget.accountUsername}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildStepperHeader() {
    return Row(
      children: [
        Expanded(
          child: _buildStepItem(
            stepNumber: 1,
            title: 'Media & Format',
            isActive: _currentStep == 1,
            isCompleted: _currentStep > 1,
          ),
        ),
        Container(width: 40, height: 2, color: _currentStep > 1 ? AppTheme.primaryColor : Colors.grey.shade300),
        Expanded(
          child: _buildStepItem(
            stepNumber: 2,
            title: 'Content & Scheduling',
            isActive: _currentStep == 2,
            isCompleted: false,
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    final color = isCompleted
        ? AppTheme.primaryColor
        : isActive
            ? AppTheme.secondaryColor
            : Colors.grey.shade400;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$stepNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ── Step 1: Media & Format ──────────────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Select Content Type',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildContentTypeCard(
                  type: 'IMAGE',
                  title: 'Single Photo',
                  subtitle: '1 high-res image (JPG, PNG)',
                  icon: Icons.photo_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildContentTypeCard(
                  type: 'CAROUSEL',
                  title: 'Carousel',
                  subtitle: '2 to 10 photos album',
                  icon: Icons.view_carousel_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildContentTypeCard(
                  type: 'REEL',
                  title: 'Reel (Video)',
                  subtitle: 'Vertical video (MP4, MOV)',
                  icon: Icons.movie_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Aspect Ratio Selection
          Row(
            children: [
              const Text(
                '2. Choose Aspect Ratio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Text(
                _mediaType == 'REEL'
                    ? '(9:16 is recommended for Reels)'
                    : '(4:5 Portrait provides highest feed engagement)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_mediaType == 'REEL') ...[
                _buildRatioChip('9:16', 'Portrait (9:16)', Icons.stay_current_portrait_rounded),
                const SizedBox(width: 12),
                _buildRatioChip('1:1', 'Square (1:1)', Icons.crop_square_rounded),
                const SizedBox(width: 12),
                _buildRatioChip('1.91:1', 'Landscape (1.91:1)', Icons.stay_current_landscape_rounded),
              ] else ...[
                _buildRatioChip('4:5', 'Portrait (4:5)', Icons.stay_current_portrait_rounded),
                const SizedBox(width: 12),
                _buildRatioChip('1:1', 'Square (1:1)', Icons.crop_square_rounded),
                const SizedBox(width: 12),
                _buildRatioChip('1.91:1', 'Landscape (1.91:1)', Icons.stay_current_landscape_rounded),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Media Upload Area
          Row(
            children: [
              const Text(
                '3. Upload Media',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 8),
              if (_mediaType == 'CAROUSEL')
                Text(
                  '(${_pickedFiles.length}/10 selected - min 2 required)',
                  style: TextStyle(
                    color: _pickedFiles.length < 2 ? Colors.amber.shade800 : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Drop/Pick Zone
          InkWell(
            onTap: _pickFiles,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _mediaType == 'REEL' ? Icons.video_call_rounded : Icons.cloud_upload_outlined,
                    size: 40,
                    color: AppTheme.secondaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mediaType == 'CAROUSEL'
                        ? 'Click to select photos for Carousel (2 to 10 photos)'
                        : _mediaType == 'REEL'
                            ? 'Click to select video for Reel (MP4 or MOV)'
                            : 'Click to select photo (JPG, PNG, WEBP)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Files are validated and rendered immediately for preview',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Display selected media
          if (_pickedFiles.isNotEmpty) ...[
            if (_mediaType == 'CAROUSEL') ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(_pickedFiles.length, (index) {
                  final file = _pickedFiles[index];
                  return Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.memory(file.bytes, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removeFile(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            '#${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: Colors.black12,
                        child: _pickedFiles.first.isVideo
                            ? const Center(child: Icon(Icons.movie_rounded, color: Colors.grey, size: 30))
                            : Image.memory(_pickedFiles.first.bytes, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFiles.first.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_pickedFiles.first.size / (1024 * 1024)).toStringAsFixed(2)} MB • ${_pickedFiles.first.mimeType}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _removeFile(0),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildContentTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _mediaType == type;

    return InkWell(
      onTap: () => _onMediaTypeChanged(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? AppTheme.secondaryColor : Colors.grey.shade600),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? AppTheme.secondaryColor : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatioChip(String ratio, String label, IconData icon) {
    final isSelected = _aspectRatio == ratio;

    return InkWell(
      onTap: () => setState(() => _aspectRatio = ratio),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Content & Scheduling ─────────────────────────────────────────────
  Widget _buildStep2() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Live Instagram Preview Mockup
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: _buildInstagramLivePreview(),
          ),
        ),
        const SizedBox(width: 24),
        const VerticalDivider(width: 1),
        const SizedBox(width: 24),

        // Right Column: Editor & Controls
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_submitError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _submitError!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Caption Editor
                Row(
                  children: [
                    const Text('Caption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    Text(
                      '${_captionController.text.length} / 2200',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _captionController.text.length > 2200 ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _captionController,
                  maxLines: 4,
                  maxLength: 2200,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                  decoration: InputDecoration(
                    hintText: 'Write a caption that engages your audience...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 6),

                // Quick Emojis
                Wrap(
                  spacing: 6,
                  children: _quickEmojis.map((emoji) {
                    return InkWell(
                      onTap: () {
                        _captionController.text += emoji;
                        _captionController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _captionController.text.length),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 14)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Hashtags
                Row(
                  children: [
                    const Text('Hashtags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '(${_hashtags.length}/30)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hashtagInputController,
                        onSubmitted: _addHashtag,
                        decoration: InputDecoration(
                          hintText: 'Add hashtag (e.g. socialmedia)',
                          prefixText: '# ',
                          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addHashtag(_hashtagInputController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Suggested Hashtags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._suggestedHashtags.map((tag) {
                      final isAdded = _hashtags.contains(tag);
                      return ActionChip(
                        label: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isAdded ? Colors.white : const Color(0xFF00376B),
                          ),
                        ),
                        backgroundColor: isAdded ? AppTheme.secondaryColor : Colors.blue.shade50,
                        onPressed: isAdded ? () => _removeHashtag(tag) : () => _addHashtag(tag),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }),
                  ],
                ),
                if (_hashtags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _hashtags.map((tag) {
                      return Chip(
                        label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _removeHashtag(tag),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),

                // Tag People
                const Text('Tag People', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagInputController,
                        onSubmitted: _addTag,
                        decoration: InputDecoration(
                          hintText: 'Enter Instagram username (e.g. meta)',
                          prefixText: '@ ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addTag(_tagInputController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Tag'),
                    ),
                  ],
                ),
                if (_userTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _userTags.map((tag) {
                      return Chip(
                        avatar: const Icon(Icons.person, size: 14),
                        label: Text('@${tag.username}', style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _removeTag(tag.username),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),

                // Location
                const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'Add location (e.g. Mumbai, India)',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Publishing Options (Publish Now vs Schedule)
                const Text('Publishing Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isScheduled = false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: !_isScheduled ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !_isScheduled ? AppTheme.primaryColor : Colors.grey.shade300,
                              width: !_isScheduled ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.send_rounded,
                                color: !_isScheduled ? AppTheme.secondaryColor : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Publish Now',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_isScheduled ? AppTheme.secondaryColor : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Publish to feed immediately',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isScheduled = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isScheduled ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isScheduled ? AppTheme.primaryColor : Colors.grey.shade300,
                              width: _isScheduled ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: _isScheduled ? AppTheme.secondaryColor : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Schedule for Later',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isScheduled ? AppTheme.secondaryColor : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Pick future date & time',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Date & Time pickers if Schedule selected
                if (_isScheduled) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Date and Time (Past dates/times disabled):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Date Picker
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final today = DateTime(now.year, now.month, now.day);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
                                    firstDate: today, // Prevent past dates!
                                    lastDate: today.add(const Duration(days: 730)), // up to 2 years ahead
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.date_range_rounded, size: 18),
                                label: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Time Picker
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedTime = picked);
                                  }
                                },
                                icon: const Icon(Icons.access_time_rounded, size: 18),
                                label: Text(_selectedTime.format(context)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '📅 Post will go live on ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)} at ${_selectedTime.format(context)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Instagram Phone Post Mockup Preview ──────────────────────────────────────
  Widget _buildInstagramLivePreview() {
    final aspectRatioVal = _getAspectRatioValue();
    final username = widget.accountUsername.isNotEmpty ? widget.accountUsername : 'sendzyy_account';
    final locationText = _locationController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.person, size: 18, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (locationText.isNotEmpty)
                        Text(
                          locationText,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, size: 20),
              ],
            ),
          ),

          // Media Box (Aspect Ratio enforced)
          Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: aspectRatioVal,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_pickedFiles.isNotEmpty) ...[
                    if (_mediaType == 'CAROUSEL') ...[
                      Image.memory(
                        _pickedFiles[_carouselPreviewIndex].bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      // Carousel Chevrons
                      if (_carouselPreviewIndex > 0)
                        Positioned(
                          left: 8,
                          child: InkWell(
                            onTap: () => setState(() => _carouselPreviewIndex--),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      if (_carouselPreviewIndex < _pickedFiles.length - 1)
                        Positioned(
                          right: 8,
                          child: InkWell(
                            onTap: () => setState(() => _carouselPreviewIndex++),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      // Slide count badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            '${_carouselPreviewIndex + 1}/${_pickedFiles.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else if (_mediaType == 'REEL') ...[
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.movie_rounded, color: Colors.white70, size: 54),
                            SizedBox(height: 8),
                            Text('Reel Video Preview', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: FaIcon(FontAwesomeIcons.instagram, color: Colors.white, size: 20),
                      ),
                    ] else ...[
                      Image.memory(
                        _pickedFiles.first.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ],
                  ] else ...[
                    const Center(
                      child: Icon(Icons.image_outlined, color: Colors.white54, size: 48),
                    ),
                  ],

                  // User tags indicator
                  if (_userTags.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '@${_userTags.first.username}${_userTags.length > 1 ? " +${_userTags.length - 1}" : ""}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Action Bar (Heart, Comment, Share, Bookmark)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.favorite_border_rounded, size: 22),
                const SizedBox(width: 14),
                const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                const SizedBox(width: 14),
                const Icon(Icons.send_rounded, size: 20),
                const Spacer(),
                const Icon(Icons.bookmark_border_rounded, size: 22),
              ],
            ),
          ),

          // Caption & Tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 12.5, height: 1.3),
                children: [
                  TextSpan(
                    text: '$username ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: _captionController.text.isNotEmpty
                        ? _captionController.text
                        : 'Your caption will appear here in the preview...',
                    style: TextStyle(
                      color: _captionController.text.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
                    ),
                  ),
                  if (_hashtags.isNotEmpty) ...[
                    const TextSpan(text: '\n\n'),
                    TextSpan(
                      text: _hashtags.map((h) => '#$h').join(' '),
                      style: const TextStyle(color: Color(0xFF00376B)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Date Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              _isScheduled
                  ? 'Scheduled: ${DateFormat('MMM dd • h:mm a').format(_computeScheduledDateTime())}'
                  : 'JUST NOW',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Dialog Bottom Footer ─────────────────────────────────────────────────────
  Widget _buildDialogFooter() {
    return Row(
      children: [
        if (_isSubmitting) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            _submitProgressText,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
        const Spacer(),
        if (_currentStep == 1) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isStep1Valid() ? () => setState(() => _currentStep = 2) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Next: Content & Preview ➔', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ] else ...[
          OutlinedButton(
            onPressed: _isSubmitting ? null : () => setState(() => _currentStep = 1),
            child: const Text('⬅ Back to Media'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isScheduled ? Colors.indigo.shade600 : AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: Icon(
              _isScheduled ? Icons.calendar_month_rounded : Icons.send_rounded,
              size: 18,
            ),
            label: Text(
              _isScheduled ? 'Schedule Post' : 'Publish to Instagram Now',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}
