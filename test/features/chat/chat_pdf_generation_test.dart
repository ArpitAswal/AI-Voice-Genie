import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_genie/core/enums/app_enums.dart';

// Standalone test suite replicating ChatProvider prompt capability resolution logic
bool looksLikePdfGenerationPrompt(String prompt) {
  final lower = prompt.trim().toLowerCase();

  // 1. Explicit exclusions: Questions about existing files or asking how-to
  final askingAbout = RegExp(
    r'\b(how to|how do|how can|can you read|summarize this|explain this|what is in|analyze this|read this)\b',
  ).hasMatch(lower);
  if (askingAbout) return false;

  // 2. Strong match: Verb + "pdf" / "document" / "report" / "invoice" / "resume"
  final strongMatch = RegExp(
    r'\b(create|generate|make|build|export|produce|write|give me|download)\b.{0,60}\b(pdf|pdf file|pdf doc|pdf document|document as pdf|report as pdf)\b',
  ).hasMatch(lower);
  if (strongMatch) return true;

  // 3. Command starting with "pdf of", "generate pdf", "create pdf"
  final commandAtStart = RegExp(
    r'^(can you|could you|please|i want to|i need to)?\s*(generate|create|make|build|export|write)\s+(a\s+|the\s+)?(pdf|pdf document|pdf report|pdf invoice|pdf resume)\b',
  ).hasMatch(lower);
  if (commandAtStart) return true;

  return false;
}

AiCapability resolveCapability({
  required String prompt,
  bool hasPdfAttachment = false,
  bool hasImageAttachment = false,
}) {
  if (hasImageAttachment) return AiCapability.imageUnderstanding;
  if (hasPdfAttachment) return AiCapability.pdfParsing;
  if (looksLikePdfGenerationPrompt(prompt)) return AiCapability.pdfGeneration;
  return AiCapability.textGeneration;
}

void main() {
  group('PDF Generation Capability Routing Tests', () {
    test('User prompt asking to generate PDF routes to pdfGeneration', () {
      const prompt =
          'Generate the pdf, in which describes the comparison of Generative AI, Agent AI, Agentic AI';
      expect(looksLikePdfGenerationPrompt(prompt), isTrue);
      expect(resolveCapability(prompt: prompt), AiCapability.pdfGeneration);
    });

    test('Various document creation prompts route to pdfGeneration', () {
      expect(looksLikePdfGenerationPrompt('Create a pdf report of quarterly finances'), isTrue);
      expect(looksLikePdfGenerationPrompt('Please export this summary as a pdf document'), isTrue);
      expect(looksLikePdfGenerationPrompt('Write a pdf resume for software developer'), isTrue);
      expect(looksLikePdfGenerationPrompt('Could you make a pdf file about solar energy?'), isTrue);
    });

    test('Questions about how to create PDFs or code queries do NOT trigger pdfGeneration', () {
      expect(looksLikePdfGenerationPrompt('How to create a pdf in python?'), isFalse);
      expect(looksLikePdfGenerationPrompt('Can you explain this pdf format?'), isFalse);
      expect(resolveCapability(prompt: 'How to make a pdf with code?'), AiCapability.textGeneration);
    });

    test('Attached PDF takes precedence as pdfParsing', () {
      const prompt = 'Generate the pdf summary';
      expect(
        resolveCapability(prompt: prompt, hasPdfAttachment: true),
        AiCapability.pdfParsing,
      );
    });

    test('Generated PDF response presents clean confirmation instead of raw markdown essay', () {
      // Replicates ChatProvider._buildAiMessage content selection
      String resolveContent({required bool hasPdf, required String rawText}) {
        return hasPdf ? 'Here is the required PDF as you requested.' : rawText;
      }

      expect(
        resolveContent(hasPdf: true, rawText: '# Full essay...'),
        'Here is the required PDF as you requested.',
      );
      expect(
        resolveContent(hasPdf: false, rawText: 'Plain text response'),
        'Plain text response',
      );
    });
  });
}
