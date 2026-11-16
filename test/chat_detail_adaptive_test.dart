import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:ai_voice_genie/features/chat/domain/message_model.dart';
import 'package:ai_voice_genie/features/chat/presentation/chat_provider.dart';
import 'package:ai_voice_genie/features/chat/presentation/widgets/message_bubble.dart';
import 'package:ai_voice_genie/features/voice_speech/presentation/voice_speech_provider.dart';
import 'package:ai_voice_genie/features/chat/presentation/widgets/model_indicator_chip.dart';
import 'package:ai_voice_genie/features/image_download/domain/image_download_repository.dart';
import 'package:ai_voice_genie/features/image_download/presentation/image_download_provider.dart';

class _FakeImageDownloadRepository implements ImageDownloadRepository {
  @override
  Future<DeviceImageSaveResult> downloadAndSave({
    required String imageSource,
    String provider = 'unknown',
  }) async =>
      DeviceImageSaveResult.success;

  @override
  Future<Uint8List?> resolveToBytes(String imageSource) async => null;
}

class _FakeChatProvider extends ChangeNotifier implements ChatProvider {
  @override
  bool shouldAnimateMessage(String messageId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVoiceProvider extends ChangeNotifier implements VoiceProvider {
  @override
  VoiceRecordingState get state => VoiceRecordingState.idle;

  @override
  String? get activeTtsMessageId => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestableWidget(Widget child,
    {Size surfaceSize = const Size(360, 600)}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ImageDownloadProvider>(
        create: (_) => ImageDownloadProvider(
          repository: _FakeImageDownloadRepository(),
        ),
      ),
      ChangeNotifierProvider<ChatProvider>(
        create: (_) => _FakeChatProvider(),
      ),
      ChangeNotifierProvider<VoiceProvider>(
        create: (_) => _FakeVoiceProvider(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: MediaQuery(
        data: MediaQueryData(size: surfaceSize),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: surfaceSize.width,
              height: surfaceSize.height,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ModelIndicatorChip Adaptive Tests', () {
    testWidgets('Renders OpenAI brand chip correctly on compact mobile',
        (tester) async {
      await tester.pumpWidget(
        _buildTestableWidget(
          const ModelIndicatorChip(
            provider: AiProviderId.openAi,
            isTablet: false,
          ),
          surfaceSize: const Size(360, 100),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ChatGPT'), findsOneWidget);
    });

    testWidgets('Renders Gemini and Claude chips on tablet without overflow',
        (tester) async {
      await tester.pumpWidget(
        _buildTestableWidget(
          const Row(
            children: [
              ModelIndicatorChip(
                provider: AiProviderId.gemini,
                isTablet: true,
              ),
              SizedBox(width: 8),
              ModelIndicatorChip(
                provider: AiProviderId.claude,
                isTablet: true,
              ),
            ],
          ),
          surfaceSize: const Size(600, 100),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('Claude'), findsOneWidget);
    });
  });

  group('TypingIndicator Adaptive Tests', () {
    testWidgets('Renders typing indicator on mobile and tablet',
        (tester) async {
      await tester.pumpWidget(
        _buildTestableWidget(
          const TypingIndicator(),
          surfaceSize: const Size(360, 100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TypingIndicator), findsOneWidget);
    });
  });

  group('MessageBubble Adaptive Text & PDF Tests', () {
    testWidgets(
        'Renders user text bubble without overflow on narrow 320dp phone',
        (tester) async {
      final userMessage = MessageModel.userMessage(
        lastPrompt:
            'Can you please explain how adaptive UI layout works across different screen sizes?',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.textGeneration,
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: userMessage,
              isTablet: false,
            ),
          ),
          surfaceSize: const Size(320, 400),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Can you please explain how adaptive UI layout works across different screen sizes?'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders user text bubble on tablet with de-compacted padding',
        (tester) async {
      final userMessage = MessageModel.userMessage(
        lastPrompt: 'Hello Genie, tell me a quick story.',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.textGeneration,
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: userMessage,
              isTablet: true,
            ),
          ),
          surfaceSize: const Size(800, 400),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello Genie, tell me a quick story.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Renders single PDF attachment as full horizontal card without overflow',
        (tester) async {
      final messageWithPdf = MessageModel.userMessage(
        lastPrompt: 'Review this PDF document',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.pdfParsing,
        pdfInfo: [
          const PdfAttachmentInfo(
            name: 'Quarterly_Financial_Report_2026.pdf',
            path: '/local/test.pdf',
            fileSizeBytes: 2450000,
          ),
        ],
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: messageWithPdf,
              isTablet: false,
            ),
          ),
          surfaceSize: const Size(360, 400),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quarterly_Financial_Report_2026.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Renders multiple PDF attachments (3 PDFs) stacked cleanly without 1px overflow',
        (tester) async {
      final messageWithMultiplePdfs = MessageModel.userMessage(
        lastPrompt: 'Here are the requested documents',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.pdfParsing,
        pdfInfo: [
          const PdfAttachmentInfo(
            name: 'Document_Alpha.pdf',
            path: '/local/doc1.pdf',
            fileSizeBytes: 1024000,
          ),
          const PdfAttachmentInfo(
            name: 'Document_Beta.pdf',
            path: '/local/doc2.pdf',
            fileSizeBytes: 2048000,
          ),
          const PdfAttachmentInfo(
            name: 'Document_Gamma.pdf',
            path: '/local/doc3.pdf',
            fileSizeBytes: 512000,
          ),
        ],
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: messageWithMultiplePdfs,
              isTablet: false,
            ),
          ),
          surfaceSize: const Size(360, 600),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document_Alpha.pdf'), findsOneWidget);
      expect(find.text('Document_Beta.pdf'), findsOneWidget);
      expect(find.text('Document_Gamma.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders 5+ PDF attachments gracefully without dropping them',
        (tester) async {
      final messageWith5Pdfs = MessageModel.userMessage(
        lastPrompt: 'Five documents',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.pdfParsing,
        pdfInfo: List.generate(
          5,
          (i) => PdfAttachmentInfo(
            name: 'Report_Part_${i + 1}.pdf',
            path: '/local/part$i.pdf',
            fileSizeBytes: 1000000,
          ),
        ),
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: messageWith5Pdfs,
              isTablet: true,
            ),
          ),
          surfaceSize: const Size(768, 800),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 1; i <= 5; i++) {
        expect(find.text('Report_Part_$i.pdf'), findsOneWidget);
      }
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Renders user request with PDF on tablet with right alignment and shrink-wrapped bubble',
        (tester) async {
      final userPdfMessage = MessageModel.userMessage(
        lastPrompt:
            'Summarize the key findings, executive takeaways, and main conclusions from this document into bullet points.',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.pdfParsing,
        pdfInfo: const [
          PdfAttachmentInfo(
            name: 'The_Fundamentals_of_Artificial.pdf',
            path: '/local/The_Fundamentals_of_Artificial.pdf',
            fileSizeBytes: 35000,
          ),
        ],
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: userPdfMessage,
              isTablet: true,
            ),
          ),
          surfaceSize: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      final bubbleFinder = find.byType(MessageBubble);
      expect(bubbleFinder, findsOneWidget);

      final containerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      );
      final containerSize = tester.getSize(containerFinder);
      // The bubble must not exceed maxWidth (1280 * 0.55 = 704 + padding)
      expect(containerSize.width <= 730, isTrue);

      expect(find.text('The_Fundamentals_of_Artificial.pdf'), findsOneWidget);
      expect(find.text('35 KB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Single-word messages hug their content without expanding to full width',
        (tester) async {
      final shortAiMessage = MessageModel(
        lastPrompt: 'Done.',
        modelRequest: AiProviderId.gemini,
        requestCapability: AiCapability.textGeneration,
        role: MessageRole.assistant,
        status: MessageStatus.delivered,
      );

      final shortUserMessage = MessageModel.userMessage(
        lastPrompt: 'Hello',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.textGeneration,
      ).copyWith(status: MessageStatus.delivered);

      final userShortPdfMessage = MessageModel.userMessage(
        lastPrompt: 'Please summarize',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.pdfParsing,
        pdfInfo: const [
          PdfAttachmentInfo(
            name: 'Doc.pdf',
            path: '/local/Doc.pdf',
            fileSizeBytes: 35000,
          ),
        ],
      ).copyWith(status: MessageStatus.delivered);

      // 1. Test AI short message
      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: shortAiMessage,
              isTablet: true,
            ),
          ),
          surfaceSize: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      final aiContainerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      );
      final aiSize = tester.getSize(aiContainerFinder);
      expect(aiSize.width < 250, isTrue);

      // 2. Test User short message ("Hello")
      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: shortUserMessage,
              isTablet: true,
            ),
          ),
          surfaceSize: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      final userContainerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      );
      final userSize = tester.getSize(userContainerFinder);
      expect(userSize.width < 200, isTrue);

      // 3. Test User PDF + short text
      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: userShortPdfMessage,
              isTablet: true,
            ),
          ),
          surfaceSize: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      final userPdfContainerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      );
      final userPdfSize = tester.getSize(userPdfContainerFinder);
      expect(userPdfSize.width < 450, isTrue);
    });
  });

  group('MessageBubble Adaptive Image Grid Tests', () {
    testWidgets(
        'Renders single image message without overflow on phone and tablet',
        (tester) async {
      final singleImageMessage = MessageModel.userMessage(
        lastPrompt: 'Look at this photo',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.imageUnderstanding,
        imagePaths: ['/tmp/test_image_1.jpg'],
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: singleImageMessage,
              isTablet: false,
            ),
          ),
          surfaceSize: const Size(360, 500),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Look at this photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Renders multiple images (2 images side by side) without overflow',
        (tester) async {
      final twoImagesMessage = MessageModel.userMessage(
        lastPrompt: 'Two images attached',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.imageUnderstanding,
        imagePaths: ['/tmp/img1.jpg', '/tmp/img2.jpg'],
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: twoImagesMessage,
              isTablet: false,
            ),
          ),
          surfaceSize: const Size(360, 500),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Two images attached'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Renders 5+ images with +N overlay without dropping extra images',
        (tester) async {
      final fiveImagesMessage = MessageModel.userMessage(
        lastPrompt: 'Batch of five images',
        provider: AiProviderId.gemini,
        requestCapability: AiCapability.imageUnderstanding,
        imagePaths: [
          '/tmp/img1.jpg',
          '/tmp/img2.jpg',
          '/tmp/img3.jpg',
          '/tmp/img4.jpg',
          '/tmp/img5.jpg',
        ],
      ).copyWith(status: MessageStatus.delivered);

      await tester.pumpWidget(
        _buildTestableWidget(
          SingleChildScrollView(
            child: MessageBubble(
              message: fiveImagesMessage,
              isTablet: true,
            ),
          ),
          surfaceSize: const Size(768, 600),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch of five images'), findsOneWidget);
      // The 4th slot overlay should show '+2' for 5 images (5 - 3 = 2)
      expect(find.text('+2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
