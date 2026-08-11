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

  /// Strips conversational greetings and AI names from the beginning of a prompt.
  /// Example: "Hey Genie, how are you?" -> "how are you?"
  String stripGreetings() {
    if (trim().isEmpty) return this;

    final regex = RegExp(
      r'^(good\s+morning|good\s+afternoon|good\s+evening|good\s+night|hello|hey|hi|greetings)[\s]*(genie|chatgpt|claude|ai|bot|assistant)?[\s,!.?]*',
      caseSensitive: false,
    );

    return replaceFirst(regex, '').trim();
  }

  ///automatic conversation title generation,
  ///similar to what systems like ChatGPT or Anthropic's Claude do.
  ///
  /// Generates the final, permanent title from the user's prompt text.
  /// Called once when the user sends the first message — never changed again.
  String generateConversationTitle() {
    if (trim().isEmpty) return "Untitled Conversation";

    String text = trim();

    // 1. Remove leading introductory fluff in a loop
    //    Handles stacked phrases like "Hey Genie, can you please tell me about..."
    final fluffRegex = RegExp(
      r'^(hey[\w\s,!?]*|hi[\w\s,!?]*|hello[\w\s,!?]*|please|can you|could you|'
      r'i want to|i need( to)?|help me( with)?|tell me( about)?|'
      r'what (is|are|was|were|do|does|did|can|could|would|should|have|has) (you|i|we)?[\s\w]*?(about|on|of|regarding)?|'
      r'do you know( about| of)?|do you have|'
      r'how (do|does|can|would|should|to) (i|we|you)?[\s\w]*?|'
      r'give me|show me|write me|write|create|explain|describe|summarize|'
      r'list|find|search for|look up|make me|make a|generate)\s+',
      caseSensitive: false,
    );

    String previousText = "";
    while (text != previousText) {
      previousText = text;
      text = text.replaceFirst(fluffRegex, '').trim();
    }

    if (text.isEmpty) return "Untitled Conversation";

    // 2. Strip leading articles/connectors ("the stars" → "stars")
    text = text
        .replaceFirst(
            RegExp(r'^(the|a|an|about|regarding|on|some)\s+',
                caseSensitive: false),
            '')
        .trim();

    if (text.isEmpty) return "Untitled Conversation";

    // 3. Take the first sentence fragment (up to first ?,!,. or newline)
    final sentenceEnd = RegExp(r'[.?!\n]');
    final match = sentenceEnd.firstMatch(text);
    if (match != null && match.start > 4) {
      text = text.substring(0, match.start).trim();
    }

    // 4. Take first 5 words max
    final words = text.split(RegExp(r'\s+'));
    final selected = words.take(5).toList();

    // 5. Rejoin and clean up trailing punctuation
    String rawTitle =
        selected.join(" ").replaceAll(RegExp(r'[^\w\s]+$'), '').trim();

    if (rawTitle.isEmpty) return "Untitled Conversation";

    // 6. Sentence Case — capitalize just the very first letter of the title
    if (rawTitle.isNotEmpty) {
      return rawTitle[0].toUpperCase() + rawTitle.substring(1).toLowerCase();
    }

    return "Untitled Conversation";
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
