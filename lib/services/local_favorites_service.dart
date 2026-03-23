import 'package:shared_preferences/shared_preferences.dart';

class LocalFavoritesService {
  static const String _favoritesKey = 'local_favorites';

  // Singleton instance
  static final LocalFavoritesService _instance =
      LocalFavoritesService._internal();
  factory LocalFavoritesService() => _instance;
  LocalFavoritesService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Get all local favorites
  Set<String> getLocalFavorites() {
    final favorites = _prefs.getStringList(_favoritesKey) ?? [];
    return favorites.toSet();
  }

  // Add to local favorites
  Future<void> addToLocalFavorites(String productId) async {
    final favorites = getLocalFavorites();
    favorites.add(productId);
    await _prefs.setStringList(_favoritesKey, favorites.toList());
  }

  // Remove from local favorites
  Future<void> removeFromLocalFavorites(String productId) async {
    final favorites = getLocalFavorites();
    favorites.remove(productId);
    await _prefs.setStringList(_favoritesKey, favorites.toList());
  }

  // Check if product is in local favorites
  bool isInLocalFavorites(String productId) {
    return getLocalFavorites().contains(productId);
  }

  // Sync local favorites with server after login
  Future<void> syncWithServer() async {
    final localFavorites = getLocalFavorites();
    if (localFavorites.isEmpty) return;

    // TODO: Add your server sync logic here
    // Example:
    // for (final productId in localFavorites) {
    //   await addToServerFavorites(productId);
    // }

    // Clear local favorites after successful sync
    await _prefs.setStringList(_favoritesKey, []);
  }
}
