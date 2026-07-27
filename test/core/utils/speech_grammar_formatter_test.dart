import 'package:ai_voice_genie/core/utils/speech_grammar_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechGrammarFormatter tests', () {
    test('formats user exact example with proper nouns, greetings, and question segmentation', () {
      const input =
          'hey Gemini is your real competitor in artificial intelligence field what makes them better against you who is better model capabilities';
      final formatted = SpeechGrammarFormatter.format(input, isFinal: true);

      expect(
        formatted,
        equals(
            'Hey Gemini, is your real competitor in artificial intelligence field? What makes them better against you? Who is better model capabilities?'),
      );
    });

    test('capitalizes proper nouns and technical terms', () {
      const input = 'i want to build a flutter app using dart and firebase with chatgpt api';
      final formatted = SpeechGrammarFormatter.format(input, isFinal: true);

      expect(
        formatted,
        equals('I want to build a Flutter app using Dart and Firebase with ChatGPT API.'),
      );
    });

    test('converts spoken punctuation words into actual symbols', () {
      const input = 'hello world comma this is a test period what is next question mark';
      final formatted = SpeechGrammarFormatter.format(input, isFinal: true);

      expect(
        formatted,
        equals('Hello world, this is a test. What is next?'),
      );
    });

    test('does not add premature period when isFinal is false', () {
      const input = 'i am speaking a long sentence';
      final formatted = SpeechGrammarFormatter.format(input, isFinal: false);

      expect(formatted, equals('I am speaking a long sentence'));
    });
  });
}
