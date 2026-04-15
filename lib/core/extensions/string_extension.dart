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
    if (trim().isEmpty) return "New Chat";

    // Normalize
    String text = toLowerCase();

    // Remove common filler phrases
    final fillers = [
      "please",
      "can you",
      "could you",
      "i want to",
      "i need",
      "help me",
      "how to",
    ];

    for (var filler in fillers) {
      text = text.replaceAll(filler, "");
    }

    // Remove punctuation
    text = text.replaceAll(RegExp(r'[^\w\s]'), '');

    // Split words
    List<String> words = text.split(RegExp(r'\s+'));

    // Remove stop words
    final stopWords = [
      "the",
      "is",
      "a",
      "an",
      "to",
      "of",
      "for",
      "and",
      "in",
      "on",
      "with"
    ];

    words.removeWhere((word) => stopWords.contains(word));

    // Take first 5–6 meaningful words
    List<String> selected = words.take(6).toList();

    if (selected.isEmpty) return "New Chat";

    // Convert to Title Case
    String title = selected.map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(" ");

    return title;
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
