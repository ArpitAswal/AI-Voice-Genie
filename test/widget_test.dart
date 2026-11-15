import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:ai_voice_genie/features/intro/presentation/viewmodel/intro_viewmodel.dart';
import 'package:ai_voice_genie/features/intro/presentation/widgets/quick_actions_section.dart';

Widget _buildTestableWidget(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('IntroViewModel Tests', () {
    test('QuickActionType contains all 6 unified action categories', () {
      expect(QuickActionType.values.length, 6);
      expect(QuickActionType.values, contains(QuickActionType.askQuestion));
      expect(QuickActionType.values, contains(QuickActionType.summarizePdf));
      expect(QuickActionType.values, contains(QuickActionType.generateImage));
      expect(QuickActionType.values, contains(QuickActionType.analyzeImage));
      expect(QuickActionType.values, contains(QuickActionType.generatePdf));
      expect(QuickActionType.values, contains(QuickActionType.generateCode));
    });
  });

  group('QuickActionsSection Widget Tests', () {
    testWidgets('Renders section title and action chips', (tester) async {
      await tester.pumpWidget(
        _buildTestableWidget(
          QuickActionsSection(onActionSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Verify section header
      expect(find.text('WHAT WOULD YOU LIKE TO DO?'), findsOneWidget);

      // Verify all 6 chips are present
      expect(find.text('Ask a question'), findsOneWidget);
      expect(find.text('Summarize PDF'), findsOneWidget);
      expect(find.text('Generate Image'), findsOneWidget);
      expect(find.text('Analyze Image'), findsOneWidget);
      expect(find.text('Generate PDF'), findsOneWidget);
      expect(find.text('Generate Code'), findsOneWidget);
    });

    testWidgets(
        'Tapping chip triggers onActionSelected with correct QuickActionType',
        (tester) async {
      QuickActionType? selectedType;

      await tester.pumpWidget(
        _buildTestableWidget(
          QuickActionsSection(
            onActionSelected: (type) => selectedType = type,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Ask a question'
      await tester.tap(find.text('Ask a question'));
      await tester.pump();
      expect(selectedType, QuickActionType.askQuestion);

      // Tap 'Summarize PDF'
      await tester.tap(find.text('Summarize PDF'));
      await tester.pump();
      expect(selectedType, QuickActionType.summarizePdf);
    });
  });
}
