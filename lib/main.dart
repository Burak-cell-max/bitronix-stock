import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih/sayı biçimlendirme verisini yükle. Bu yapılmazsa
  // DateFormat('...', 'tr_TR') LocaleDataException fırlatır ve ilgili
  // widget (ör. Finans hareket listesi) gri bir hata kutusuna döner.
  await initializeDateFormatting('tr_TR', null);
  Intl.defaultLocale = 'tr_TR';

  var firebaseReady = true;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    firebaseReady = false;
  }
  runApp(
    ProviderScope(
      child: BitronixApp(firebaseReady: firebaseReady),
    ),
  );
}
