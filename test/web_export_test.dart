@TestOn('chrome')
library;

// Regression test for the web export bug: file_picker's saveFile() throws
// UnimplementedError on every browser, so web must go through
// utils/file_export.dart instead. Only meaningful under `flutter test
// --platform chrome` - the VM platform never exercises the web branch.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forge_master_optimizer/repository/storage.dart';
import 'package:forge_master_optimizer/screens/settings_screen.dart';
import 'package:forge_master_optimizer/state/app_state.dart';

void main() {
  testWidgets('Export to .json succeeds on web', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await Storage.open();
    final state = await AppState.load(storage);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Export to .json'));
    await tester.pumpAndSettle();

    expect(find.text('Exported backup.'), findsOneWidget);
  });
}
