import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uchet_s_d/app_state.dart';
import 'package:uchet_s_d/auth/firebase_auth/auth_util.dart';
import 'package:uchet_s_d/backend/schema/users_record.dart';
import 'package:uchet_s_d/component/edit_schet/edit_schet_widget.dart';
import 'package:uchet_s_d/flutter_flow/internationalization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
      'account editor remains open after completed setup and expired editing window',
      (tester) async {
    final previous = currentUserDocument;
    addTearDown(() => currentUserDocument = previous);
    // A synthetic legacy profile exercises the real editor's former early exit.
    // No Firebase service is read: the document reference is a local value only.
    currentUserDocument = UsersRecord.getDocumentFromData({
      'role': 'owner',
      'data_locked': true,
      'onboarding_complete': true,
      'onboarding_locked_steps': {'accounts': true},
      'temporary_editing_enabled': false,
      'temporary_editing_until': DateTime(2000),
    }, FirebaseFirestore.instance.doc('users/synthetic-editing-test'));
    final state = FFAppState();
    await state.initializePersistedState();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(
        localizationsDelegates: [
          FFLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ru')],
        home: Scaffold(
            body: SingleChildScrollView(
                child: EditSchetWidget(
          tip: 'bank',
          title: 'Synthetic editable account',
          summa: 100,
          coment: 'SYNTHETIC TEST ONLY',
          id: null,
        ))),
      ),
    ));
    await tester.pump();
    expect(find.byType(TextFormField), findsAtLeastNWidgets(3));
    expect(find.text('Редактирование отключено.'), findsNothing);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Synthetic editable account');
  });
}
