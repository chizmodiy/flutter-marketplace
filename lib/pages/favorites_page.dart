import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/common_header.dart';
import '../services/product_service.dart';
import '../models/product.dart';
import 'package:intl/intl.dart';
import '../pages/home_page.dart'; // Import ViewMode enum
import '../widgets/product_card_list_item.dart'; // Import ProductCardListItem
import '../widgets/product_card.dart';
import '../theme/app_colors.dart';
import '../services/favorites_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.contentKey});

  final GlobalKey<FavoritesPageState>? contentKey;

  @override
  State<FavoritesPage> createState() => FavoritesPageState();
}

class FavoritesPageState extends State<FavoritesPage> {
  final ProductService _productService = ProductService();
  final _favoritesService = FavoritesService();

  Set<String> _favoriteProductIds = {};
  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  ViewMode _currentViewMode = ViewMode.grid4;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favoriteIds = await _favoritesService.getFavorites();
      setState(() {
        _favoriteProductIds = favoriteIds;
      });
      await _loadProducts();
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _loadProducts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_favoriteProductIds.isEmpty) {
        setState(() {
          _products = [];
          _isLoading = false;
        });
        return;
      }

      final products = await _productService.getProductsByIds(
        _favoriteProductIds.toList(),
      );

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    try {
      final isInFavorites = await _favoritesService.isInFavorites(product.id);

      if (isInFavorites) {
        await _favoritesService.removeFromFavorites(product.id);
        setState(() {
          _favoriteProductIds.remove(product.id);
          _products.removeWhere((p) => p.id == product.id);
        });
      } else {
        await _favoritesService.addToFavorites(product.id);
        setState(() {
          _favoriteProductIds.add(product.id);
        });
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  // Add refreshProducts method
  void refreshProducts() {
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonHeader(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/heart-rounded.svg',
                      width: 48,
                      height: 48,
                      colorFilter: const ColorFilter.mode(
                        AppColors.zinc200,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Тут будуть ваші обрані оголошення',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF18181B), // zinc-900
                        fontSize: 20,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Додавайте оголошення в обране, щоб мати до них швидкий доступ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF71717A), // zinc-500
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(13, 20, 13, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок + перемикач виду
                  Row(
                    children: [
                      const Text(
                        'Обране',
                        style: TextStyle(
                          color: Color(0xFF161817),
                          fontSize: 28,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      // Кнопка перемикання виду
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentViewMode =
                                _currentViewMode == ViewMode.grid4
                                ? ViewMode.list
                                : ViewMode.grid4;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE4E4E7)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _currentViewMode == ViewMode.grid4
                                  ? Icons.grid_view
                                  : Icons.view_list,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _currentViewMode == ViewMode.grid4
                        ? GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 280,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              return ProductCard(
                                id: product.id,
                                title: product.title,
                                price: product.formattedPrice,
                                date: DateFormat(
                                  'dd.MM.yyyy',
                                ).format(product.createdAt),
                                region: product.region,
                                images: product.photos,
                                isNegotiable: product.isNegotiable,
                                isFavorite: _favoriteProductIds.contains(
                                  product.id,
                                ),
                                onFavoriteToggle: () =>
                                    _toggleFavorite(product),
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/product-detail',
                                    arguments: {'id': product.id},
                                  );
                                  _loadFavorites();
                                },
                              );
                            },
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: ProductCardListItem(
                                  id: product.id,
                                  title: product.title,
                                  price: product.formattedPrice,
                                  date: DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(product.createdAt),
                                  region: product.region,
                                  images: product.photos,
                                  isNegotiable: product.isNegotiable,
                                  isFavorite: _favoriteProductIds.contains(
                                    product.id,
                                  ),
                                  onFavoriteToggle: () =>
                                      _toggleFavorite(product),
                                  onTap: () async {
                                    await Navigator.pushNamed(
                                      context,
                                      '/product-detail',
                                      arguments: {'id': product.id},
                                    );
                                    _loadFavorites();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
