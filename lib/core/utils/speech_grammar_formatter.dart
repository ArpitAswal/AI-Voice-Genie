/// Utility class to enhance speech-to-text dictation grammar, capitalization,
/// proper noun formatting, and sentence segmentation.
class SpeechGrammarFormatter {
  SpeechGrammarFormatter._();

  /// Case-insensitive mapping of proper nouns, AI names, brands, and acronyms
  /// to their correct capitalization.
  static const Map<String, String> _properNouns = {
    'gemini': 'Gemini',
    'chatgpt': 'ChatGPT',
    'gpt-4': 'GPT-4',
    'gpt-3': 'GPT-3',
    'gpt': 'GPT',
    'claude': 'Claude',
    'anthropic': 'Anthropic',
    'openai': 'OpenAI',
    'llama': 'Llama',
    'copilot': 'Copilot',
    'deepmind': 'DeepMind',
    'genie': 'Genie',
    'ai': 'AI',
    'agi': 'AGI',
    'ml': 'ML',
    'nlp': 'NLP',
    'llm': 'LLM',
    'rag': 'RAG',
    'google': 'Google',
    'apple': 'Apple',
    'microsoft': 'Microsoft',
    'meta': 'Meta',
    'amazon': 'Amazon',
    'android': 'Android',
    'ios': 'iOS',
    'windows': 'Windows',
    'macos': 'macOS',
    'linux': 'Linux',
    'flutter': 'Flutter',
    'dart': 'Dart',
    'firebase': 'Firebase',
    'hive': 'Hive',
    'sqlite': 'SQLite',
    'react': 'React',
    'vue': 'Vue',
    'angular': 'Angular',
    'node': 'Node',
    'python': 'Python',
    'java': 'Java',
    'kotlin': 'Kotlin',
    'swift': 'Swift',
    'github': 'GitHub',
    'git': 'Git',
    'api': 'API',
    'sdk': 'SDK',
    'ui': 'UI',
    'ux': 'UX',
    'http': 'HTTP',
    'https': 'HTTPS',
    'url': 'URL',
    'uri': 'URI',
    'json': 'JSON',
    'xml': 'XML',
    'html': 'HTML',
    'css': 'CSS',
    'sql': 'SQL',
    'nosql': 'NoSQL',
    'cpu': 'CPU',
    'gpu': 'GPU',
    'tpu': 'TPU',
    'ram': 'RAM',
    'rom': 'ROM',
    'os': 'OS',
    'id': 'ID',
    'ip': 'IP',
    'faq': 'FAQ',
    'seo': 'SEO',
  };

  /// Common question-starting two-word phrases that indicate a new clause or sentence.
  static const List<String> _questionStarters = [
    'what is', 'what are', 'what makes', 'what do', 'what does', 'what can', 'what will', 'what should', 'what would',
    'who is', 'who are', 'who has', 'who can', 'who will', 'who should', 'who would',
    'why is', 'why do', 'why does', 'why are', 'why did', 'why should', 'why would', 'why can',
    'how is', 'how are', 'how do', 'how does', 'how can', 'how will', 'how should', 'how would', 'how to', 'how much', 'how many',
    'where is', 'where are', 'where do', 'where does', 'where can', 'where will',
    'when is', 'when will', 'when do', 'when does', 'when can',
    'which is', 'which are', 'which can', 'which will',
    'can you', 'could you', 'would you', 'will you', 'should you',
    'do you', 'did you', 'have you', 'has it', 'is it', 'are you', 'is there', 'are there',
    'can i', 'could i', 'should i', 'may i', 'will i', 'am i',
  ];

  /// Enhances the raw transcribed [text] by applying grammar cleanup, proper noun
  /// capitalization, question clause segmentation, and sentence punctuation.
  ///
  /// Set [isFinal] to true when speech recording has completed to ensure closing
  /// periods or question marks are placed at the end of the input.
  static String format(String text, {bool isFinal = false}) {
    if (text.trim().isEmpty) return text.trim();

    // 1. Clean up multiple whitespaces and trim edges
    String result = text.trim().replaceAll(RegExp(r'\s+'), ' ');

    // 2. Replace spoken punctuation keywords if present as standalone words
    result = _replaceSpokenPunctuation(result);

    // 3. Format greetings (e.g. "hey Gemini" -> "hey Gemini, ")
    result = _formatGreetings(result);

    // 4. Segment fused question clauses by inserting question marks
    result = _segmentQuestionClauses(result);

    // 5. Capitalize proper nouns and technical terms
    result = _capitalizeProperNouns(result);

    // 6. Capitalize the first letter of each sentence
    result = _capitalizeSentences(result);

    // 7. Add terminating punctuation if this is the final transcript or ends with a question clause
    if (isFinal) {
      result = _addTerminatingPunctuation(result);
    }

    return result;
  }

  /// Converts spoken punctuation words into actual symbols.
  static String _replaceSpokenPunctuation(String input) {
    String out = input;
    out = out.replaceAll(RegExp(r'\b(full stop|period)\b', caseSensitive: false), '.');
    out = out.replaceAll(RegExp(r'\b(question mark)\b', caseSensitive: false), '?');
    out = out.replaceAll(RegExp(r'\b(exclamation mark|exclamation point)\b', caseSensitive: false), '!');
    out = out.replaceAll(RegExp(r'\b(comma)\b', caseSensitive: false), ',');
    out = out.replaceAll(RegExp(r'\b(new line|next line)\b', caseSensitive: false), '\n');
    // Fix any awkward spacing created around symbols (e.g., "word , next" -> "word, next")
    out = out.replaceAll(RegExp(r'\s+([.,!?])'), r'\1');
    out = out.replaceAll(RegExp(r'([.,!?])(?=[a-zA-Z0-9])'), r'\1 ');
    return out;
  }

  /// Inserts a comma after common assistant vocative greetings.
  static String _formatGreetings(String input) {
    // Regex matching greeting words followed by names (e.g., Hey Gemini, Hi Genie, Hello AI)
    final greetingRegex = RegExp(
      r'^(hey|hi|hello|okay|ok)\s+(gemini|genie|ai|chatgpt|claude|siri|google|assistant)(?!\s*[,.!?])',
      caseSensitive: false,
    );
    return input.replaceAllMapped(greetingRegex, (match) {
      // Return matched greeting + comma + space
      return '${match.group(0)},';
    });
  }

  /// Scans for internal question-starter phrases and inserts question marks at clause boundaries.
  static String _segmentQuestionClauses(String input) {
    // We split words to check positions and insert punctuation where appropriate
    final words = input.split(' ');
    if (words.length <= 4) return input;

    final List<String> processed = [];
    for (int i = 0; i < words.length; i++) {
      final currentWord = words[i];
      // Check if this word and the next form a known question starter phrase
      if (i > 2 && i < words.length - 1) {
        final phrase = '${currentWord.toLowerCase()} ${words[i + 1].toLowerCase()}';
        if (_questionStarters.contains(phrase)) {
          // Check if previous word already has punctuation
          final prevWord = processed.last;
          if (!RegExp(r'[.,!?]$').hasMatch(prevWord)) {
            // Append question mark to the previous clause before starting the new question
            processed[processed.length - 1] = '$prevWord?';
          }
        }
      }
      processed.add(currentWord);
    }
    return processed.join(' ');
  }

  /// Capitalizes known proper nouns, AI terms, and technical acronyms.
  static String _capitalizeProperNouns(String input) {
    final words = input.split(' ');
    final List<String> out = [];
    for (final word in words) {
      // Extract word without leading/trailing punctuation for lookup
      final cleanWord = word.replaceAll(RegExp(r'^[.,!?]+|[.,!?]+$'), '');
      final lower = cleanWord.toLowerCase();
      if (_properNouns.containsKey(lower)) {
        // Replace the clean word portion with its exact proper capitalization
        final replacement = _properNouns[lower]!;
        out.add(word.replaceFirst(cleanWord, replacement));
      } else {
        out.add(word);
      }
    }
    return out.join(' ');
  }

  /// Capitalizes the first letter of strings and letters following sentence terminators.
  static String _capitalizeSentences(String input) {
    if (input.isEmpty) return input;

    final chars = input.split('');
    bool capitalizeNext = true;

    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        if (capitalizeNext) {
          chars[i] = char.toUpperCase();
          capitalizeNext = false;
        }
      } else if (RegExp(r'[.!?\n]').hasMatch(char)) {
        // Next alphabetical character after a terminator should be capitalized
        capitalizeNext = true;
      }
    }
    return chars.join('');
  }

  /// Appends closing punctuation to the end of the text if it is missing.
  static String _addTerminatingPunctuation(String input) {
    if (input.isEmpty) return input;
    final trimmed = input.trim();
    if (RegExp(r'[.,!?]$').hasMatch(trimmed)) return trimmed;

    // Determine if the final clause is a question by checking its last interrogative words
    final lower = trimmed.toLowerCase();
    bool isQuestion = false;

    // Check if the sentence starts with a question word or after the last punctuation starts with one
    final lastClause = trimmed.split(RegExp(r'[.!?,]\s*')).last.trim().toLowerCase();
    for (final starter in _questionStarters) {
      if (lastClause.startsWith(starter) || lower.startsWith(starter)) {
        isQuestion = true;
        break;
      }
    }

    // Also check single question words at the start of the last clause
    final singleStarters = ['who ', 'what ', 'where ', 'when ', 'why ', 'how ', 'which ', 'can ', 'could ', 'would ', 'will ', 'is ', 'are ', 'do ', 'does ', 'did '];
    for (final starter in singleStarters) {
      if (lastClause.startsWith(starter)) {
        isQuestion = true;
        break;
      }
    }

    return isQuestion ? '$trimmed?' : '$trimmed.';
  }
}
