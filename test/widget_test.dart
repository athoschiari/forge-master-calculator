// Smoke test: boots the app with an in-memory store and checks it renders.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forge_master_optimizer/main.dart';
import 'package:forge_master_optimizer/repository/storage.dart';
import 'package:forge_master_optimizer/state/app_state.dart';

void main() {
  testWidgets('App boots to the dashboard', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await Storage.open();
    final state = await AppState.load(storage);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const ForgeMasterApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The dashboard header and the nav destination both read "Dashboard".
    expect(find.text('Dashboard'), findsWidgets);
    // Headline metric labels are present.
    expect(find.text('Dmg / sec'), findsWidgets);
  });
}
