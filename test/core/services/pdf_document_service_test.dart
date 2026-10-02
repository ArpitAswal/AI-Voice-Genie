import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_genie/core/services/pdf_document_service.dart';

void main() {
  group('PdfDocumentService Tests', () {
    test('extractDocumentTitle extracts heading from markdown when present', () {
      const markdown = '# Comparison of Generative AI and Agentic AI\n\nSome body text here.';
      const prompt = 'Generate the pdf';

      final title = PdfDocumentService.extractDocumentTitle(prompt, markdown);
      expect(title, 'Comparison of Generative AI and Agentic AI');
    });

    test('extractDocumentTitle extracts long heading up to 120 chars correctly', () {
      const markdown = '# Architectural Analysis: Generative AI vs. Agent AI vs. Agentic AI\n\nBody text.';
      const prompt = 'Generate the pdf, in which describes the comparison of Generative AI, Agent AI, Agentic AI.';

      final title = PdfDocumentService.extractDocumentTitle(prompt, markdown);
      expect(title, 'Architectural Analysis: Generative AI vs. Agent AI vs. Agentic AI');
    });

    test('extractDocumentTitle derives clean title from conversational prompt if no H1', () {
      const markdown = 'No heading text at all.';
      const prompt = 'Generate the pdf, in which describes the comparison of Generative AI, Agent AI, Agentic AI.';

      final title = PdfDocumentService.extractDocumentTitle(prompt, markdown);
      expect(title, 'Comparison of Generative AI, Agent AI, Agentic AI');
    });

    test('compileMarkdownToPdf compiles Markdown into valid PDF bytes', () async {
      const title = 'Generative AI vs Agentic AI';
      const markdown = '''
# Generative AI vs Agentic AI

## 1. Executive Summary
Generative AI generates passive content like text and images.
Agentic AI executes autonomous actions in environments.

* Key Point 1: Autonomous decision making
* Key Point 2: Tool execution

| Feature | Generative AI | Agentic AI |
| --- | --- | --- |
| Focus | Synthesis | Action |
| Autonomy | Low | High |
''';

      final bytes = await PdfDocumentService.instance.compileMarkdownToPdf(
        title: title,
        markdownContent: markdown,
      );

      expect(bytes.isNotEmpty, isTrue);
      // Valid PDF files always start with '%PDF-' (0x25, 0x50, 0x44, 0x46)
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('compileMarkdownToPdf compiles blockquotes, callouts, and code blocks cleanly', () async {
      const title = 'Gemini Pricing & Capabilities';
      const markdown = '''
# Gemini Pricing & Capabilities

> **Key Takeaway 1:** Adaptive reasoning tokens bill at standard output rates.
> Developers can set thinking budgets.

```
GEMINI TIERS
Standard API: \$0.75 / \$3.75
```

* **Bold Feature**: Works without replacing with dollar signs.
* Check [google.dev](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQFDNCQ0T4nLY1YOh5vF7ch) link.

| Tier | Input | Output |
| :--- | :---: | ---: |
| **Standard** | \$0.75 | \$3.75 |
''';

      final bytes = await PdfDocumentService.instance.compileMarkdownToPdf(
        title: title,
        markdownContent: markdown,
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });
  });
}
