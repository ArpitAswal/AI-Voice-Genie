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

  /// Strips conversational greetings, AI name references, and pleasantries
  /// from the beginning of a user prompt.
  ///
  /// Examples:
  /// - "Hey Gemini, Good evening, how well are you? Generate an image of..."
  ///   -> "Generate an image of..."
  /// - "Hello Genie, how are you? Can you summarize this?"
  ///   -> "Can you summarize this?"
  /// - "Good morning AI! What is quantum computing?"
  ///   -> "What is quantum computing?"
  String stripGreetings() {
    var text = trim();
    if (text.isEmpty) return text;

    // Matches conversational greetings with optional audience ("there", "everyone")
    // and optional AI/assistant names.
    final greetingRegex = RegExp(
      r'^(good\s+(morning|afternoon|evening|night|day)|hello|hey|hi|howdy|greetings|yo|hola|welcome|dear)\b(\s+(there|everyone|all|folks))?(\s+(gemini|genie|voice\s*genie|ai\s*voice\s*genie|chatgpt|gpt[-\s\w]*|claude|deepseek|groq|llama|meta|copilot|siri|assistant|ai|bot|friend|buddy))?[\s,!.?:;~-]*',
      caseSensitive: false,
    );

    // Matches standalone AI names/mentions at the beginning (e.g. "Gemini, ...", "Genie: ...")
    final aiNameRegex = RegExp(
      r'^(gemini|genie|voice\s*genie|ai\s*voice\s*genie|chatgpt|gpt[-\s\w]*|claude|deepseek|groq|llama|meta|copilot|siri|assistant|ai|bot|friend|buddy)[\s,!.?:;~-]*',
      caseSensitive: false,
    );

    // Matches pleasantries, chit-chat, and well-wishes at the beginning
    final pleasantryRegex = RegExp(
      r"^(how\s+(are\s+you(\s+doing)?(\s+today)?|well\s+are\s+you|are\s+things|is\s+it\s+going|have\s+you\s+been|do\s+you\s+do|r\s+u)|how'?s\s+(it\s+going|everything|life)|what'?s\s+up|hope\s+(you('re|\s+are)\s+(doing\s+well|well|good|fine|having\s+a\s+good\s+day)|all\s+is\s+well|this\s+finds\s+you\s+well)|(nice|good|great)\s+to\s+(meet|see)\s+you)[\s,!.?:;~-]*",
      caseSensitive: false,
    );

    bool changed = true;
    while (changed && text.isNotEmpty) {
      changed = false;
      if (greetingRegex.hasMatch(text)) {
        final newText = text.replaceFirst(greetingRegex, '').trim();
        if (newText != text) {
          text = newText;
          changed = true;
          continue;
        }
      }
      if (aiNameRegex.hasMatch(text)) {
        final newText = text.replaceFirst(aiNameRegex, '').trim();
        if (newText != text) {
          text = newText;
          changed = true;
          continue;
        }
      }
      if (pleasantryRegex.hasMatch(text)) {
        final newText = text.replaceFirst(pleasantryRegex, '').trim();
        if (newText != text) {
          text = newText;
          changed = true;
          continue;
        }
      }
    }

    if (text.isNotEmpty) {
      text = text[0].toUpperCase() + text.substring(1);
    }

    return text;
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
