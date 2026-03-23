import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/favorites_service.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<bool> isLoggedIn() async {
    return _supabase.auth.currentSession != null;
  }

  Future<void> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        throw 'Authentication failed';
      }

      // Sync local favorites with server after successful login
      await FavoritesService().syncLocalFavoritesWithServer();
    } catch (e) {
      rethrow;
    }
  }

  // ... rest of your existing methods ...
}
