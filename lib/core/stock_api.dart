import 'package:firebase_auth/firebase_auth.dart';

/// Bitronix Stock — kendi sunucumuzdaki yardımcı API.
/// Fatura deposu ve e-posta doğrulama kodu buradan geçer (Firebase dışı).
class StockApi {
  StockApi._();

  /// bitronixdev.com VPS'indeki uç nokta kökü.
  static const String base = 'https://bitronixdev.com/stock-api';

  /// Giriş yapmış kullanıcının taze Firebase ID token'ını döndürür.
  static Future<String> idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Oturum açık değil.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Kimlik doğrulanamadı.');
    }
    return token;
  }

  static Future<Map<String, String>> authHeaders() async => {
        'Authorization': 'Bearer ${await idToken()}',
      };
}
