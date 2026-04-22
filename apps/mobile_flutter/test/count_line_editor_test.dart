import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/features/sites/screens/count_line_editor_screen.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CountLineEditorScreen', () {
    testWidgets(
      'renders title, segmented IN/OUT control, and disables Save until '
      'both lines are complete',
      (tester) async {
        // Empty videoPath short-circuits the canvas to the "pick a
        // backdrop" empty state, which is enough to render the editor's
        // chrome without a real frame extractor.
        await tester.pumpWidget(_wrap(
          const CountLineEditorScreen(videoPath: ''),
        ));
        await tester.pumpAndSettle();

        final l10n =
            await AppLocalizations.delegate.load(const Locale('en'));

        expect(find.text(l10n.countLineEditorTitle), findsOneWidget);
        // Segmented mode picker offers both IN and OUT.
        expect(find.text(l10n.countLineEditorModeIn), findsOneWidget);
        expect(find.text(l10n.countLineEditorModeOut), findsOneWidget);

        // The Save button is rendered but disabled when no lines drawn.
        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, l10n.roiEditorSave),
        );
        expect(saveButton.onPressed, isNull);
      },
    );

    testWidgets(
      'seeds the editor state from an existing CountLineConfig',
      (tester) async {
        const initial = CountLineConfig(
          inLine: [Offset(0.1, 0.4), Offset(0.9, 0.45)],
          outLine: [Offset(0.05, 0.8), Offset(0.95, 0.85)],
        );
        await tester.pumpWidget(_wrap(
          const CountLineEditorScreen(videoPath: '', initial: initial),
        ));
        await tester.pumpAndSettle();

        final l10n =
            await AppLocalizations.delegate.load(const Locale('en'));
        // With both lines pre-set, Save should be enabled.
        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, l10n.roiEditorSave),
        );
        expect(saveButton.onPressed, isNotNull);
      },
    );
  });
}
