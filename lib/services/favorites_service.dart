import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final String _favoritesKey = 'local_favorites';
  late SharedPreferences _prefs;
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Get favorites (combines both local and server favorites)
  Future<Set<String>> getFavorites() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      return await _getServerFavorites();
    } else {
      return _getLocalFavorites();
    }
  }

  // Add to favorites (local or server based on auth status)
  Future<void> addToFavorites(String productId) async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      await _addToServerFavorites(productId);
    } else {
      await _addToLocalFavorites(productId);
    }
  }

  // Remove from favorites (local or server based on auth status)
  Future<void> removeFromFavorites(String productId) async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      await _removeFromServerFavorites(productId);
    } else {
      await _removeFromLocalFavorites(productId);
    }
  }

  // Check if product is in favorites
  Future<bool> isInFavorites(String productId) async {
    final favorites = await getFavorites();
    return favorites.contains(productId);
  }

  // Local favorites methods
  Set<String> _getLocalFavorites() {
    final favorites = _prefs.getStringList(_favoritesKey) ?? [];
    return favorites.toSet();
  }

  Future<void> _addToLocalFavorites(String productId) async {
    final favorites = _getLocalFavorites();
    favorites.add(productId);
    await _prefs.setStringList(_favoritesKey, favorites.toList());
  }

  Future<void> _removeFromLocalFavorites(String productId) async {
    final favorites = _getLocalFavorites();
    favorites.remove(productId);
    await _prefs.setStringList(_favoritesKey, favorites.toList());
  }

  // Server favorites methods
  Future<Set<String>> _getServerFavorites() async {
    try {
      final response = await _supabase
          .from('profiles') // Changed to profiles table
          .select('favorite_products') // Select the favorite_products array
          .eq('id', _supabase.auth.currentUser!.id)
          .single();

      final List<dynamic> data =
          response['favorite_products'] as List<dynamic>? ?? [];
      return data.map((item) => item.toString()).toSet();
    } catch (e) {
      print(
        'Error getting server favorites from profiles: $e',
      ); // Updated error message
      return {};
    }
  }

  Future<void> _addToServerFavorites(String productId) async {
    try {
      final currentFavorites =
          await _getServerFavorites(); // Get current favorites
      if (!currentFavorites.contains(productId)) {
        currentFavorites.add(productId);
        await _supabase
            .from('profiles')
            .update({
              'favorite_products': currentFavorites
                  .toList(), // Update with modified list
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _supabase.auth.currentUser!.id);
      }
    } catch (e) {
      print('Error adding to server favorites in profiles: $e');
    }
  }

  Future<void> _removeFromServerFavorites(String productId) async {
    try {
      final currentFavorites =
          await _getServerFavorites(); // Get current favorites
      if (currentFavorites.remove(productId)) {
        // Try to remove, and only update if successful
        await _supabase
            .from('profiles')
            .update({
              'favorite_products': currentFavorites
                  .toList(), // Update with modified list
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _supabase.auth.currentUser!.id);
      }
    } catch (e) {
      print('Error removing from server favorites in profiles: $e');
    }
  }

  // Sync local favorites with server after login
  Future<void> syncLocalFavoritesWithServer() async {
    final localFavorites = _getLocalFavorites();
    if (localFavorites.isEmpty) return;

    try {
      // Add all local favorites to server
      for (final productId in localFavorites) {
        await _addToServerFavorites(productId);
      }

      // Clear local favorites after successful sync
      await _prefs.setStringList(_favoritesKey, []);
    } catch (e) {
      print('Error syncing local favorites with server: $e');
    }
  }
}
