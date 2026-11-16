import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:ai_voice_genie/features/chat/domain/conversation_model.dart';
import 'package:ai_voice_genie/features/chat/presentation/widgets/custom_conversation_card.dart';
import 'package:ai_voice_genie/features/chat/presentation/widgets/empty_history_view.dart';

Widget _buildTestableWidget(Widget child, {Size? surfaceSize}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: surfaceSize?.width ?? 400,
          height: surfaceSize?.height ?? 800,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('CustomConversationCard Adaptive & Interactive Tests', () {
    final sampleConversation = ConversationModel(
      id: 'test-1',
      title: 'Adaptive UI Design for History Screen',
      lastMessage:
          'Let us make sure the layout scales smoothly on all devices.',
      lastMessageAt: DateTime(2026, 11, 15, 14, 30),
      lastProvider: AiProviderId.gemini,
    );

    testWidgets('Renders card details in normal mode without overflow',
        (tester) async {
      bool tapped = false;
      bool longPressed = false;

      await tester.pumpWidget(
        _buildTestableWidget(
          CustomConversationCard(
            conversation: sampleConversation,
            onTap: () => tapped = true,
            onLongPress: () => longPressed = true,
          ),
          surfaceSize: const Size(360, 200),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text('Adaptive UI Design for History Screen'), findsOneWidget);
      expect(
        find.text(
            'Let us make sure the layout scales smoothly on all devices.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byType(CustomConversationCard));
      expect(tapped, isTrue);

      await tester.longPress(find.byType(CustomConversationCard));
      expect(longPressed, isTrue);
    });

    testWidgets('Renders selection indicators in selection mode',
        (tester) async {
      await tester.pumpWidget(
        _buildTestableWidget(
          CustomConversationCard(
            conversation: sampleConversation,
            isSelectionMode: true,
            isSelected: false,
            onTap: () {},
          ),
          surfaceSize: const Size(360, 200),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      // Now with isSelected = true
      await tester.pumpWidget(
        _buildTestableWidget(
          CustomConversationCard(
            conversation: sampleConversation,
            isSelectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
          surfaceSize: const Size(360, 200),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets(
        'Renders correctly with empty lastMessage in fixed height grid cell',
        (tester) async {
      final noMessageConversation = ConversationModel(
        id: 'test-2',
        title: 'Empty Message Thread',
        lastMessage: '',
        lastMessageAt: DateTime(2026, 11, 15, 10, 0),
        lastProvider: AiProviderId.openAi,
      );

      await tester.pumpWidget(
        _buildTestableWidget(
          SizedBox(
            height: 140.0,
            child: CustomConversationCard(
              conversation: noMessageConversation,
              onTap: () {},
            ),
          ),
          surfaceSize: const Size(320, 140),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empty Message Thread'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EmptyHistoryView Adaptive Layout Tests', () {
    testWidgets('Renders on mobile without overflowing screen bounds',
        (tester) async {
      await tester.pumpWidget(
        _buildTestableWidget(
          const EmptyHistoryView(isTablet: false),
          surfaceSize: const Size(360, 640),
        ),
      );
      await tester.pump();

      expect(find.text('New Conversation'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders on tablet with constrained button width',
        (tester) async {
      await tester.pumpWidget(
        _buildTestableWidget(
          const EmptyHistoryView(isTablet: true),
          surfaceSize: const Size(800, 1000),
        ),
      );
      await tester.pump();

      expect(find.text('New Conversation'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
