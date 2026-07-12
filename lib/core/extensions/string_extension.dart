import 'package:intl/intl.dart';

/// String utility extensions used throughout the app.
///
/// Usage: 'hello world'.capitalize, 'test@email.com'.isValidEmail
extension StringExtension on String {
  /// Capitalize the first letter of the string
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalize first letter of each word
  String get titleCase {
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Returns true if string is a valid email address
  bool get isValidEmail {
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(trim());
  }

  /// Truncate string to maxLength with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  /// Returns true if string is null or empty after trimming
  bool get isNullOrEmpty => trim().isEmpty;

  /// Mask an API key for display — shows first 4 and last 4 characters
  /// Example: 'sk-abc123xyz789' → 'sk-a...789'
  String get maskedApiKey {
    if (length <= 8) return '****';
    return '${substring(0, 4)}...${substring(length - 4)}';
  }

  ///automatic conversation title generation,
  ///similar to what systems like ChatGPT or Anthropic’s Claude do.
  String generateConversationTitle() {
    if (trim().isEmpty) return "Untitled Conversation";

    String text = trim();

    // 1. Remove introductory fluff ONLY if it appears at the start of the prompt.
    // This stops it from breaking phrases like "How to tie a tie".
    final fluffRegex = RegExp(
      r'^(hey[\w\s,]*|hi[\w\s,]*|hello[\w\s,]*|please|can you|could you|i want to|i need( to)?|help me( with)?|tell me( about)?|what is|how do i)\s+',
      caseSensitive: false,
    );

    // Keep removing fluff if there are stacked phrases (e.g., "Hey Gemini, please can you...")
    String previousText = "";
    while (text != previousText) {
      previousText = text;
      text = text.replaceFirst(fluffRegex, '').trim();
    }

    if (text.isEmpty) return "Untitled Conversation";

    // 2. Take the first 5-6 meaningful words, KEEPING stop words for grammar.
    List<String> words = text.split(RegExp(r'\s+'));
    List<String> selected = words.take(5).toList();

    // 3. Rejoin and clean up trailing punctuation (so we don't end on a comma or question mark)
    String rawTitle = selected.join(" ").replaceAll(RegExp(r'[^\w\s]+$'), '');

    // 4. Convert to proper Title Case
    String title = rawTitle.split(' ').map((word) {
      if (word.isEmpty) return "";
      // Capitalize first letter, lowercase the rest
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(" ");

    return title.isEmpty ? "Untitled Conversation" : title;
  }
}

/// DateTime formatting extensions for conversation timestamps.
///
/// Usage: DateTime.now().toTimeString, message.timestamp.toConversationDate
extension DateTimeExtension on DateTime {
  /// Format: '2:30 PM'
  String get toTimeString => DateFormat('h:mm a').format(this);

  /// Format: 'Jan 15, 2024'
  String get toDateString => DateFormat('MMM d, yyyy').format(this);

  /// Format: 'Today', 'Yesterday', or date string
  String get toConversationDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(year, month, day);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return toDateString;
  }

  /// Format for message timestamp: time if today, date+time if older
  String get toMessageTimestamp {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(year, month, day);

    if (date == today) return toTimeString;
    return '$toConversationDate $toTimeString';
  }

  /// Returns true if this date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

/// Nullable String extensions
extension NullableStringExtension on String? {
  bool get isNullOrEmpty => this == null || this!.trim().isEmpty;
  String get orEmpty => this ?? '';
}
