import 'package:flutter/material.dart';

/// Modern, dynamic CircleAvatar for WhatsApp contacts.
/// - If [avatarUrl] is provided, displays the image via NetworkImage.
/// - If [name] is a real name, generates a deterministic vibrant Material color and displays 2-letter initials (e.g. "KM", "SJ").
/// - If only a phone number is available, displays a sleek person icon with a dedicated seed-derived color.
class ContactAvatar extends StatelessWidget {
  final String? name;
  final String? contactId;
  final String? avatarUrl;
  final double radius;

  const ContactAvatar({
    super.key,
    this.name,
    this.contactId,
    this.avatarUrl,
    this.radius = 20,
  });

  static const List<Color> _avatarColors = [
    Color(0xFF00A884), // WhatsApp Emerald
    Color(0xFF0284C7), // Sky Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF97316), // Orange
    Color(0xFFEAB308), // Amber
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Green
    Color(0xFFF43F5E), // Rose
  ];

  /// Returns true if [s] consists purely of phone number characters (digits, +, spaces, dashes, parentheses).
  static bool isNumeric(String? s) {
    if (s == null) return false;
    final clean = s.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    return clean.isNotEmpty && RegExp(r'^\d+$').hasMatch(clean);
  }

  Color _getColor(String seed) {
    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = (seed.codeUnitAt(i) + ((hash << 5) - hash)) & 0xFFFFFFFF;
    }
    return _avatarColors[hash.abs() % _avatarColors.length];
  }

  String _getInitials(String displayName) {
    // Strip emojis and non-alphanumeric punctuation to isolate human name characters
    final cleanAlpha = displayName.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim();
    final target = cleanAlpha.isNotEmpty ? cleanAlpha : displayName.trim();
    if (target.isEmpty) return '?';

    final parts = target.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = parts[0].characters.first.toUpperCase();
      final second = parts[1].characters.first.toUpperCase();
      return '$first$second';
    }
    final chars = target.characters.take(2).toList();
    return chars.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSeed = (name != null && name!.isNotEmpty && !isNumeric(name))
        ? name!
        : (contactId ?? 'User');
    final color = _getColor(effectiveSeed);

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.15),
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }

    final hasRealName = name != null && name!.trim().isNotEmpty && !isNumeric(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: hasRealName
          ? Text(
              _getInitials(name!),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.78,
                letterSpacing: 0.5,
              ),
            )
          : Icon(
              Icons.person_rounded,
              color: Colors.white.withValues(alpha: 0.95),
              size: radius * 1.15,
            ),
    );
  }
}
