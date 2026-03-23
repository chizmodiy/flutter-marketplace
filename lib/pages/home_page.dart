import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui';
import '../widgets/common_header.dart';
import '../widgets/product_card.dart';
import '../services/product_service.dart';
import '../models/product.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';
import '../widgets/product_card_list_item.dart'; // Import ProductCardListItem
import '../pages/filter_page.dart'; // Import FilterPage
import 'dart:async'; // Add this import for Timer
import '../pages/map_page.dart'; // Import MapPage
import '../widgets/auth_bottom_sheet.dart'; // Import AuthBottomSheet
import '../services/filter_manager.dart';
import '../widgets/keyboard_dismisser.dart'; // Import FilterManager
import '../services/favorites_service.dart';

enum ViewMode { grid8, grid4, list }

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.contentKey});

  final GlobalKey<HomeContentState>? contentKey;

  @override
  Widget build(BuildContext context) {
    return wrapWithKeyboardDismisser(
      Scaffold(
        backgroundColor: Colors.white,
        appBar: const CommonHeader(),
        body: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: HomeContent(key: contentKey),
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent> {
  final ProductService _productService = ProductService();
  final ProfileService _profileService = ProfileService();
  final ScrollController _scrollController = ScrollController();
  final FilterManager _filterManager = FilterManager();

  List<Product> _products = [];
  List<Product> _horizontalProducts = [];
  bool _isLoading = false;
  bool _isHorizontalLoading = false; // Add loading state for horizontal list
  bool _hasMore = true;
  int _currentPage = 0;
  String?
  _sortBy; // Can be 'price_asc', 'price_desc', or null (for default by date)
  ViewMode _currentViewMode = ViewMode.grid4; // Changed from _isGrid
  String? _errorMessage;
  String? _horizontalErrorMessage; // Add error state for horizontal list
  String? _currentUserId;
  Set<String> _favoriteProductIds = {};
  bool _isViewDropdownOpen = false; // New state variable
  bool _isSortDropdownOpen = false; // New state variable
  final TextEditingController _searchController =
      TextEditingController(); // Search controller
  String _searchQuery = ''; // Current search query
  Timer? _searchDebounceTimer; // Timer for debouncing search
  final LayerLink _sortLayerLink = LayerLink(); // LayerLink for sort dropdown
  final LayerLink _viewLayerLink = LayerLink(); // LayerLink for view dropdown
  String? _selectedDisplayCurrency = 'UAH'; // Changed to UAH as default
  final FocusNode _searchFocusNode =
      FocusNode(); // NEW: FocusNode for search input
  bool _isSearchInputFocused = false; // NEW: State for search input focus
  Map<String, double> _globalPriceRange = {
    'min': 0.0,
    'max': 100000.0,
  }; // NEW: Global price range state

  // Helper method to check for meaningful active filters (excluding default currency)
  bool get _hasMeaningfulFilters {
    final currentFilters = _filterManager.currentFilters;
    if (currentFilters.isEmpty) {
      return false;
    }
    // Перевіряємо, чи є фільтри, окрім дефолтної валюти UAH
    return currentFilters.length > 1 ||
        (currentFilters.length == 1 && currentFilters['currency'] != 'UAH');
  }

  bool get _areFiltersOrSortActive {
    final isActive =
        _searchQuery.isNotEmpty ||
        _hasMeaningfulFilters ||
        _sortBy != null ||
        _isSearchInputFocused;
    return isActive;
  }

  void _onFiltersChanged() {
    if (!mounted) return;
    final filters = _filterManager.currentFilters;
    final currentSearchQuery = filters['searchQuery'] as String? ?? '';
    setState(() {
      _searchQuery = currentSearchQuery;
      _searchController.text = currentSearchQuery;
      _currentPage = 0;
      _hasMore = true;
    });
    _loadProducts();
  }

  @override
  void initState() {
    super.initState();
    print('DEBUG (HomePage): initState called');
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    print('DEBUG (HomePage): Current user ID: $_currentUserId');
    final filters = _filterManager.currentFilters;
    final initialSearchQuery = filters['searchQuery'] as String? ?? '';
    if (initialSearchQuery.isNotEmpty) {
      _searchQuery = initialSearchQuery;
      _searchController.text = initialSearchQuery;
    }
    _filterManager.addListener(_onFiltersChanged);
    _loadProducts();
    _loadFavorites();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _loadGlobalPriceRange();

    Future.delayed(const Duration(milliseconds: 100), () {
      _loadHorizontalProducts();
    });
  }

  // NEW METHOD: Load global min/max price range
  Future<void> _loadGlobalPriceRange() async {
    final currentCurrency = _selectedDisplayCurrency ?? 'UAH';
    final priceRange = await _productService.getGlobalMinMaxPrice(
      currentCurrency,
    );
    setState(() {
      _globalPriceRange = priceRange;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final filters = _filterManager.currentFilters;
    final currentSearchQuery = filters['searchQuery'] as String? ?? '';
    if (currentSearchQuery != _searchQuery) {
      _searchQuery = currentSearchQuery;
      _searchController.text = currentSearchQuery;
      _loadProducts();
    }
    _loadFavorites();
  }

  @override
  void dispose() {
    _filterManager.removeListener(_onFiltersChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    final hasFocus = _searchFocusNode.hasFocus;
    if (_isSearchInputFocused != hasFocus && mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isSearchInputFocused = hasFocus);
      });
    }
  }

  Future<void> _loadProducts() async {
    print(
      'DEBUG (HomePage): _loadProducts called - _isLoading: $_isLoading, _hasMore: $_hasMore',
    );

    if (_isLoading) {
      print(
        'DEBUG (HomePage): _loadProducts called but already loading, skipping',
      );
      return;
    }

    if (!_hasMore) {
      print(
        'DEBUG (HomePage): _loadProducts called but no more products, skipping',
      );
      return;
    }

    print(
      'DEBUG (HomePage): _loadProducts called, _currentPage: $_currentPage',
    );
    print('DEBUG (HomePage): _searchQuery: "$_searchQuery"');
    print('DEBUG (HomePage): _hasMeaningfulFilters: $_hasMeaningfulFilters');
    print('DEBUG (HomePage): _sortBy: $_sortBy');
    print(
      'DEBUG (HomePage): _selectedDisplayCurrency: $_selectedDisplayCurrency',
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Очищуємо список продуктів при першому завантаженні
      if (_currentPage == 0) {
        _products.clear();
      }
    });
    print('DEBUG (HomePage): _isLoading set to true');

    final currentFilters = _filterManager.currentFilters;

    try {
      List<Product> fetchedProducts = [];

      if (_searchQuery.isNotEmpty || _hasMeaningfulFilters || _sortBy != null) {
        // Original logic: load products based on search/filters/sort
        print('DEBUG (HomePage): Loading products with filters/search/sort');
        fetchedProducts = await _productService.getProducts(
          limit: 10,
          offset: _currentPage * 10,
          searchQuery: _searchQuery,
          categoryId: currentFilters['category'],
          subcategoryId: currentFilters['subcategory'],
          region: currentFilters['region'],
          minPrice: currentFilters['minPrice'],
          maxPrice: currentFilters['maxPrice'],
          hasDelivery: currentFilters['hasDelivery'],
          sortBy: _sortBy,
          isFree: currentFilters['isFree'],
          minArea: currentFilters['minArea'],
          maxArea: currentFilters['maxArea'],
          minYear: currentFilters['minYear'],
          maxYear: currentFilters['maxYear'],
          brand: currentFilters['car_brand'],
          minMileage: currentFilters['minMileage'],
          maxMileage: currentFilters['maxMileage'],
          size: currentFilters['size'],
          condition: currentFilters['condition'],
          jobType: currentFilters['job_type'],
          conditionType: currentFilters['condition_type'],
          radiusR: currentFilters['radius_r'],
          genderType: currentFilters['gender_type'],
          realEstateType: currentFilters['real_estate_type'],
          targetCurrency: _selectedDisplayCurrency,
          makeId: currentFilters['make_id'],
          modelId: currentFilters['model_id'],
          styleId: currentFilters['style_id'],
          modelYearId: currentFilters['model_year_id'],
          minCarYear: currentFilters['minCarYear'] != null
              ? int.tryParse(currentFilters['minCarYear'].toString())
              : null,
          maxCarYear: currentFilters['maxCarYear'] != null
              ? int.tryParse(currentFilters['maxCarYear'].toString())
              : null,
        );
      } else {
        // New logic: load recommendations if no filters/search active
        print('DEBUG (HomePage): Loading recommendations (no filters/search)');
        final viewedIds = await _profileService.getViewedProductIds();
        print('DEBUG (HomePage): Viewed product IDs: $viewedIds');
        Set<String> categoriesFromViewed = {};

        if (viewedIds.isNotEmpty) {
          final viewedProductsForCategories = await _productService
              .getProductsByIds(viewedIds.toList());
          for (var product in viewedProductsForCategories) {
            if (product.categoryId != null) {
              categoriesFromViewed.add(product.categoryId!);
            }
          }
        }

        if (categoriesFromViewed.isNotEmpty) {
          // Try to load from a randomly selected viewed category for this page
          List<String> shuffledCategories = categoriesFromViewed.toList()
            ..shuffle();
          String? categoryToFetchFrom = shuffledCategories.isNotEmpty
              ? shuffledCategories[0]
              : null;

          if (categoryToFetchFrom != null) {
            try {
              fetchedProducts = await _productService.getProducts(
                limit: 10,
                offset: _currentPage * 10,
                categoryId: categoryToFetchFrom,
                sortBy: 'random',
                targetCurrency: _selectedDisplayCurrency,
                jobType: currentFilters['job_type'],
                conditionType: currentFilters['condition_type'],
                size: currentFilters['size'],
                radiusR: currentFilters['radius_r'],
                genderType: currentFilters['gender_type'],
                realEstateType: currentFilters['real_estate_type'],
              );
            } catch (e) {
              // If category specific load fails, log and fallback
              print(
                'Error loading products from category $categoryToFetchFrom: $e',
              );
              fetchedProducts = []; // Ensure it's empty to trigger fallback
            }
          }
        }

        // Fallback to general random products if no viewed categories or category-specific load failed/returned empty
        if (fetchedProducts.isEmpty) {
          print(
            'DEBUG (HomePage): No recommendations found, loading random products',
          );
          fetchedProducts = await _productService.getProducts(
            limit: 10,
            offset: _currentPage * 10,
            sortBy: 'random',
            targetCurrency: _selectedDisplayCurrency,
            jobType: currentFilters['job_type'],
            conditionType: currentFilters['condition_type'],
            size: currentFilters['size'],
            radiusR: currentFilters['radius_r'],
            genderType: currentFilters['gender_type'],
            realEstateType: currentFilters['real_estate_type'],
          );
        }
      }

      print('DEBUG (HomePage): Fetched ${fetchedProducts.length} products');
      setState(() {
        _products.addAll(fetchedProducts);
        _currentPage++;
        // Якщо отримано менше 10 товарів, то більше немає
        _hasMore = fetchedProducts.length == 10;
        _isLoading = false;
      });
      print('DEBUG (HomePage): _hasMore set to $_hasMore');
      print('DEBUG (HomePage): _isLoading set to false');
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadHorizontalProducts() async {
    if (_isHorizontalLoading) return;

    setState(() {
      _isHorizontalLoading = true;
      _horizontalErrorMessage = null;
    });

    try {
      final viewedIds = await _profileService.getViewedProductIds();

      List<Product> viewedProducts = [];
      if (viewedIds.isNotEmpty) {
        viewedProducts = await _productService.getProductsByIds(
          viewedIds.toList(),
        );
      }

      setState(() {
        _horizontalProducts = viewedProducts; // Only viewed products
        _isHorizontalLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _isHorizontalLoading = false;
        _horizontalErrorMessage = e.toString();
      });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favoritesService = FavoritesService();
      final favoriteIds = await favoritesService.getFavorites();
      setState(() {
        _favoriteProductIds = favoriteIds;
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  void _showAuthBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => AuthBottomSheet(
        title: 'Тут будуть ваші оголошення',
        subtitle:
            'Увійдіть у профіль, щоб переглядати, створювати або зберігати оголошення.',
        onLoginPressed: () {
          Navigator.of(context).pop(); // Закриваємо bottom sheet
          Navigator.of(context).pushNamed('/auth');
        },
        onCancelPressed: () {
          Navigator.of(context).pop(); // Закриваємо bottom sheet
        },
      ),
    );
  }

  Future<void> _toggleFavorite(Product product) async {
    final favoritesService = FavoritesService();

    try {
      final isInFavorites = await favoritesService.isInFavorites(product.id);

      if (isInFavorites) {
        await favoritesService.removeFromFavorites(product.id);
        setState(() {
          _favoriteProductIds.remove(product.id);
        });
      } else {
        await favoritesService.addToFavorites(product.id);
        setState(() {
          _favoriteProductIds.add(product.id);
        });
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  void _onScroll() {
    print(
      'DEBUG (HomePage): _onScroll called - pixels: ${_scrollController.position.pixels}, maxExtent: ${_scrollController.position.maxScrollExtent}',
    );
    print('DEBUG (HomePage): _isLoading: $_isLoading, _hasMore: $_hasMore');

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      print('DEBUG (HomePage): _onScroll triggered - loading more products');
      _loadProducts();
    }
  }

  void _onSortChanged(String? newSortBy) {
    setState(() {
      // Якщо нове сортування таке ж, як поточне, то скидаємо сортування
      if (_sortBy == newSortBy) {
        _sortBy = null; // Скидаємо сортування
      } else {
        _sortBy = newSortBy; // Встановлюємо нове сортування
      }
      _isSortDropdownOpen = false; // Close dropdown after selection
      _products = [];
      _currentPage = 0;
      _hasMore = true;
      _errorMessage = null;
    });
    _loadProducts();
  }

  void _toggleView() {
    setState(() {
      _isViewDropdownOpen = !_isViewDropdownOpen;
      // Закриваємо sort dropdown якщо відкриваємо view dropdown
      if (_isViewDropdownOpen) {
        _isSortDropdownOpen = false;
      }
    });
  }

  void _onViewModeSelected(ViewMode mode) {
    setState(() {
      _currentViewMode = mode;
      _isViewDropdownOpen = false; // Close dropdown after selection
      _products = [];
      _currentPage = 0;
      _hasMore = true;
      _errorMessage = null;
    });
    _loadProducts();
  }

  // Helper method to count active filters
  int _getActiveFiltersCount() {
    int count = 0;
    final currentFilters = _filterManager.currentFilters;
    final currentCurrency = _selectedDisplayCurrency ?? 'UAH';

    // Отримуємо глобальні мін/макс ціни з вже завантаженого стану
    double effectiveGlobalMinPrice = _globalPriceRange['min'] ?? 0.0;
    double effectiveGlobalMaxPrice = _globalPriceRange['max'] ?? 100000.0;

    // Якщо поточна валюта не UAH, конвертуємо глобальні ціни в UAH для порівняння
    if (currentCurrency.toLowerCase() != 'uah') {
      effectiveGlobalMinPrice = _productService.convertToUAH(
        effectiveGlobalMinPrice,
        currentCurrency,
      );
      effectiveGlobalMaxPrice = _productService.convertToUAH(
        effectiveGlobalMaxPrice,
        currentCurrency,
      );
    }

    if (currentFilters.isNotEmpty) {
      // Категорія + підкатегорія = 1 фільтр
      bool hasCategoryFilter = false;
      if (currentFilters['category'] != null &&
          currentFilters['category'].toString().isNotEmpty) {
        hasCategoryFilter = true;
      }
      if (currentFilters['subcategory'] != null &&
          currentFilters['subcategory'].toString().isNotEmpty) {
        hasCategoryFilter = true;
      }
      if (hasCategoryFilter) {
        count++;
      }

      // Ціна = 1 фільтр
      bool hasPriceFilter = false;
      if (currentFilters['minPrice'] != null &&
          currentFilters['minPrice'].toString().isNotEmpty) {
        // Порівнюємо з глобальним мінімумом для поточної валюти (тепер в UAH)
        final currentMinPrice =
            double.tryParse(currentFilters['minPrice'].toString()) ?? 0.0;
        if (currentMinPrice != effectiveGlobalMinPrice) {
          hasPriceFilter = true;
        }
      }
      if (currentFilters['maxPrice'] != null &&
          currentFilters['maxPrice'].toString().isNotEmpty) {
        // Порівнюємо з глобальним максимумом для поточної валюти (тепер в UAH)
        final currentMaxPrice =
            double.tryParse(currentFilters['maxPrice'].toString()) ?? 100000.0;
        if (currentMaxPrice != effectiveGlobalMaxPrice) {
          hasPriceFilter = true;
        }
      }
      if (hasPriceFilter) {
        count++;
      }

      // Безкоштовно = 1 фільтр
      if (currentFilters['is_free'] == true) {
        count++;
      }

      // Валюта (не гривня) = 1 фільтр
      if (currentFilters['currency'] != null &&
          currentFilters['currency'].toString().isNotEmpty &&
          currentFilters['currency'].toString().toLowerCase() != 'uah') {
        count++;
      }

      // Інші фільтри (якщо є)
      for (var entry in currentFilters.entries) {
        String key = entry.key;
        if (key != 'category' &&
            key != 'subcategory' &&
            key != 'min_price' &&
            key != 'max_price' &&
            key != 'is_free' &&
            key != 'currency') {
          if (entry.value != null && entry.value.toString().isNotEmpty) {
            if (entry.value is List) {
              if ((entry.value as List).isNotEmpty) {
                count++;
              }
            } else {
              count++;
            }
          }
        }
      }
    }
    return count;
  }

  void _showFilterBottomSheet() async {
    final Map<String, dynamic>? newFilters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FilterPage(initialFilters: _filterManager.currentFilters),
      ),
    );

    if (newFilters != null) {
      if (newFilters.isEmpty) {
        _filterManager.clearFilters();
        setState(() {
          _searchQuery = '';
          _searchController.clear();
        });
      } else {
        _filterManager.setFilters(newFilters);
        final searchQuery = newFilters['searchQuery'] as String? ?? '';
        if (searchQuery != _searchQuery) {
          setState(() {
            _searchQuery = searchQuery;
            _searchController.text = searchQuery;
          });
        }
      }
      setState(() {
        _products = [];
        _currentPage = 0;
        _hasMore = true;
        _errorMessage = null;
        if (newFilters.isNotEmpty) {
          _selectedDisplayCurrency = newFilters['currency'] as String? ?? 'UAH';
        } else {
          _selectedDisplayCurrency = 'UAH'; // Дефолтне значення
        }
      });
      _loadProducts(); // Reload products with new filters
    }
  }

  void refreshProducts() {
    setState(() {
      _products = [];
      _currentPage = 0;
      _hasMore = true;
      _errorMessage = null;
      _searchQuery = '';
      _searchController.clear();
      _filterManager.clearFilters();
      _sortBy = null;
    });
    _loadProducts();
  }

  // Helper method to build the dropdown menu for view modes
  Widget _buildViewModeDropdown() {
    return CompositedTransformFollower(
      link: _viewLayerLink,
      showWhenUnlinked: false,
      offset: const Offset(
        -180,
        52,
      ), // 44px (висота кнопки) + 8px (відступ), зміщено вліво на 180px
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(16, 24, 40, 0.03),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color.fromRGBO(16, 24, 40, 0.03),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEAECF0), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdownMenuItem(
              'Сітка',
              ViewMode.grid4,
              Icons.grid_view_outlined,
            ),
            _buildDropdownMenuItem(
              'Список',
              ViewMode.list,
              Icons.view_list_outlined,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build individual dropdown menu items
  Widget _buildDropdownMenuItem(String text, ViewMode mode, IconData icon) {
    final bool isSelected = _currentViewMode == mode;
    return GestureDetector(
      onTap: () => _onViewModeSelected(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: isSelected ? const Color(0xFFFAFAFA) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF101828), size: 20), // Gray-900
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: const Color(0xFF101828), // Gray-900
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.5,
                    letterSpacing: isSelected ? 0.16 : 0,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check,
                  size: 20,
                  color: const Color(0xFF015873),
                ), // Primary color
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build the dropdown menu for sorting
  Widget _buildSortDropdown() {
    return CompositedTransformFollower(
      link: _sortLayerLink,
      showWhenUnlinked: false,
      offset: const Offset(
        -180,
        52,
      ), // 44px (висота кнопки) + 8px (відступ), зміщено вліво на 180px
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(16, 24, 40, 0.03),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color.fromRGBO(16, 24, 40, 0.03),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEAECF0), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortDropdownMenuItem('Від новіших', null),
            _buildSortDropdownMenuItem('Від дешевших', 'price_asc'),
            _buildSortDropdownMenuItem('Від дорогих', 'price_desc'),
          ],
        ),
      ),
    );
  }

  // Helper method to build individual dropdown menu items for sorting
  Widget _buildSortDropdownMenuItem(String text, String? sortByValue) {
    final bool isSelected = _sortBy == sortByValue;
    return GestureDetector(
      onTap: () => _onSortChanged(sortByValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: isSelected ? const Color(0xFFFAFAFA) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: const Color(0xFF101828), // Gray-900
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.5,
                    letterSpacing: isSelected ? 0.16 : 0,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check,
                  size: 20,
                  color: const Color(0xFF015873),
                ), // Primary color
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row (map button moved under search)
                    Row(
                      children: [
                        const Text(
                          'Головна',
                          style: TextStyle(
                            color: Color(0xFF161817),
                            fontSize: 28,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const Spacer(),
                        // Sort button
                        CompositedTransformTarget(
                          link: _sortLayerLink,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSortDropdownOpen = !_isSortDropdownOpen;
                                _isViewDropdownOpen = false;
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _sortBy != null
                                      ? const Color(0xFF015873)
                                      : const Color(0xFFE4E4E7),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/icons/switch-vertical-01.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    _sortBy != null
                                        ? const Color(0xFF015873)
                                        : Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // View button
                        CompositedTransformTarget(
                          link: _viewLayerLink,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isViewDropdownOpen = !_isViewDropdownOpen;
                                _isSortDropdownOpen = false;
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE4E4E7),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Search row (controls moved to title row)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F3F3),
                              borderRadius: BorderRadius.circular(200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF838583),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: _onSearchChanged,
                                    focusNode: _searchFocusNode,
                                    textInputAction: TextInputAction.done,
                                    decoration: InputDecoration(
                                      hintText: 'Пошук',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 0,
                                          ),
                                      isDense: true,
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF838583),
                                        fontSize: 16,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w400,
                                        height: 1.0,
                                        letterSpacing: 0.16,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // controls moved to title row
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row under search: Filter and Map buttons
                    Row(
                      children: [
                        // Filter button (pill design)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _showFilterBottomSheet();
                            },
                            child: Builder(
                              builder: (context) {
                                final activeFiltersCount =
                                    _getActiveFiltersCount();
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          side: BorderSide(
                                            width: 1,
                                            color: activeFiltersCount > 0
                                                ? const Color(0xFF015873)
                                                : const Color(0xFFE4E4E7),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            200,
                                          ),
                                        ),
                                        shadows: const [
                                          BoxShadow(
                                            color: Color(0x0C101828),
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.filter_alt_outlined,
                                            size: 20,
                                            color: Colors.black,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Фільтр',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                              height: 1.40,
                                              letterSpacing: 0.14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (activeFiltersCount > 0)
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF015873),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$activeFiltersCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Map button (pill design)
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                useRootNavigator: true,
                                builder: (context) => const MapPage(),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: const ShapeDecoration(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    width: 1,
                                    color: Color(0xFFE4E4E7),
                                  ),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(200),
                                  ),
                                ),
                                shadows: [
                                  BoxShadow(
                                    color: Color(0x0C101828),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/map-02.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.black,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Карта',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      height: 1.40,
                                      letterSpacing: 0.14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Horizontal recommendations section
                    Visibility(
                      visible:
                          !_areFiltersOrSortActive &&
                          _horizontalProducts
                              .isNotEmpty, // Приховуємо, якщо активні фільтри, сортування або немає нещодавно переглянутих
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Нещодавно переглянуті',
                              style: TextStyle(
                                color: Color(0xFF161817),
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 256,
                            child: _isHorizontalLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _horizontalErrorMessage != null
                                ? Center(child: Text(_horizontalErrorMessage!))
                                : _horizontalProducts.isEmpty
                                ? const Center(
                                    child: Text('Немає рекомендацій'),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _horizontalProducts.length,
                                    itemBuilder: (context, index) {
                                      final product =
                                          _horizontalProducts[index];
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right:
                                              index !=
                                                  _horizontalProducts.length - 1
                                              ? 12
                                              : 0,
                                        ),
                                        child: SizedBox(
                                          width: 200,
                                          child: ProductCard(
                                            id: product.id,
                                            title: product.title,
                                            price: product.formattedPrice,
                                            date: DateFormat(
                                              'dd.MM.yyyy',
                                            ).format(product.createdAt),
                                            region: product.region,
                                            images: product.images,
                                            isNegotiable: product.isNegotiable,
                                            isFavorite: _favoriteProductIds
                                                .contains(product.id),
                                            isFree: product.isFree,
                                            imageHeight:
                                                174, // нижча висота для горизонтального списку, щоб уникнути overflow
                                            onFavoriteToggle: () =>
                                                _toggleFavorite(product),
                                            onTap: () async {
                                              print(
                                                'DEBUG (HomePage): Horizontal ProductCard onTap called for product ID: ${product.id}',
                                              );
                                              await _onProductView(product);
                                              try {
                                                await Navigator.of(
                                                  context,
                                                ).pushNamed(
                                                  '/product-detail',
                                                  arguments: {'id': product.id},
                                                );
                                                print(
                                                  'DEBUG (HomePage): Horizontal ProductCard navigation completed successfully',
                                                );
                                              } catch (e) {
                                                print(
                                                  'ERROR (HomePage): Horizontal ProductCard navigation failed: $e',
                                                );
                                              }
                                              _loadFavorites();
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Vertical recommendations section
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Рекомендовано вам',
                        style: TextStyle(
                          color: Color(0xFF161817),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Products list as SliverList for better mobile performance
              if (_isLoading && _products.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                )
              else if (_products.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('Немає товарів'),
                    ),
                  ),
                )
              else if (_currentViewMode == ViewMode.grid4)
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent:
                        280, // Фіксована висота рядка для стабільного гріда
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= _products.length) return null;
                    final product = _products[index];
                    return ProductCard(
                      id: product.id,
                      title: product.title,
                      price: product.formattedPrice,
                      date: DateFormat('dd.MM.yyyy').format(product.createdAt),
                      region: product.region,
                      images: product.images,
                      isNegotiable: product.isNegotiable,
                      isFavorite: _favoriteProductIds.contains(product.id),
                      isFree: product.isFree,
                      onFavoriteToggle: () => _toggleFavorite(product),
                      onTap: () => _onProductTap(product),
                    );
                  }, childCount: _products.length),
                )
              else if (_currentViewMode == ViewMode.grid8)
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= _products.length) return null;
                    final product = _products[index];
                    return ProductCard(
                      id: product.id,
                      title: product.title,
                      price: product.formattedPrice,
                      date: DateFormat('dd.MM.yyyy').format(product.createdAt),
                      region: product.region,
                      images: product.images,
                      isNegotiable: product.isNegotiable,
                      isFavorite: _favoriteProductIds.contains(product.id),
                      isFree: product.isFree,
                      onFavoriteToggle: () => _toggleFavorite(product),
                      onTap: () => _onProductTap(product),
                    );
                  }, childCount: _products.length),
                )
              else // ListView mode
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= _products.length) return null;
                    final product = _products[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ProductCardListItem(
                        id: product.id,
                        title: product.title,
                        price: product.formattedPrice,
                        date: DateFormat(
                          'dd.MM.yyyy',
                        ).format(product.createdAt),
                        region: product.region,
                        images: product.images,
                        isNegotiable: product.isNegotiable,
                        isFavorite: _favoriteProductIds.contains(product.id),
                        onFavoriteToggle: () => _toggleFavorite(product),
                        onTap: () => _onProductTap(product),
                      ),
                    );
                  }, childCount: _products.length),
                ),
              // Loading indicator at bottom
              if (_isLoading && _products.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_isSortDropdownOpen ||
            _isViewDropdownOpen ||
            _isSearchInputFocused) // NEW: Додаємо _isSearchInputFocused
          GestureDetector(
            onTap: () {
              setState(() {
                _isSortDropdownOpen = false;
                _isViewDropdownOpen = false;
                _searchFocusNode.unfocus(); // NEW: Unfocus search input
              });
            },
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        if (_isSortDropdownOpen) _buildSortDropdown(),
        if (_isViewDropdownOpen) _buildViewModeDropdown(),
      ],
    );
  }

  void _onSearchChanged(String value) {
    if (_searchDebounceTimer?.isActive ?? false) _searchDebounceTimer!.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      _filterManager.updateFilter('searchQuery', value.isEmpty ? null : value);
      setState(() {
        _searchQuery = value;
        _products = [];
        _currentPage = 0;
        _hasMore = true;
        _errorMessage = null;
      });
      _loadProducts();
    });
  }

  // Add method to update viewed categories when viewing product details
  Future<void> _onProductView(Product product) async {
    await _profileService.addToViewedList(product.id);
    _loadHorizontalProducts(); // Reload recommendations
  }

  // Method to handle product tap
  Future<void> _onProductTap(Product product) async {
    await _onProductView(product);
    try {
      await Navigator.of(
        context,
      ).pushNamed('/product-detail', arguments: {'id': product.id});
    } catch (e) {
      print('ERROR (HomePage): Navigation failed: $e');
    }
    _loadFavorites();
  }
}
