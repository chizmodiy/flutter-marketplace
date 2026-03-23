import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../services/product_service.dart';
import '../models/product.dart';
import '../widgets/common_header.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../services/profile_service.dart';
import '../pages/filter_page.dart'; // Додаю імпорт FilterPage
import '../services/filter_manager.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_bottom_sheet.dart';
import '../widgets/keyboard_dismisser.dart';
import 'dart:ui';
import 'dart:async'; // Додаю для Timer
import 'package:cached_network_image/cached_network_image.dart';

class Pin extends StatelessWidget {
  final String count;
  const Pin({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 32,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 2,
            child: Container(
              width: 24,
              height: 24,
              padding: const EdgeInsets.all(0),
              decoration: ShapeDecoration(
                color: const Color(0xFF0292B2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(200),
                ),
              ),
              child: Center(
                child: Text(
                  count,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    height: 1.30,
                    letterSpacing: 0.24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Comments extends StatefulWidget {
  final List<Product> products;
  const Comments({super.key, required this.products});

  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> {
  final ProfileService _profileService = ProfileService();
  Set<String> _favoriteProductIds = {};
  bool _loadingFavorites = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await _profileService.getFavoriteProductIds();
    setState(() {
      _favoriteProductIds = ids;
      _loadingFavorites = false;
    });
  }

  Future<void> _toggleFavorite(Product product) async {
    if (_favoriteProductIds.contains(product.id)) {
      await _profileService.removeFavoriteProduct(product.id);
      setState(() {
        _favoriteProductIds.remove(product.id);
      });
    } else {
      await _profileService.addFavoriteProduct(product.id);
      setState(() {
        _favoriteProductIds.add(product.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 13, right: 13, bottom: 34),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E4E7),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.products.length} оголошень',
                style: const TextStyle(
                  color: Color(0xFF52525B),
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  letterSpacing: 0.16,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(200),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingFavorites
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: widget.products.length,
                    itemBuilder: (context, index) {
                      final product = widget.products[index];
                      final isFavorite = _favoriteProductIds.contains(
                        product.id,
                      );
                      return MapListingCard(
                        product: product,
                        isFavorite: isFavorite,
                        onTap: () async {
                          await Navigator.of(context).pushNamed(
                            '/product-detail',
                            arguments: {'id': product.id},
                          );
                          _loadFavorites();
                        },
                        onFavoriteToggle: () => _toggleFavorite(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Січня',
      'Лютого',
      'Березня',
      'Квітня',
      'Травня',
      'Червня',
      'Липня',
      'Серпня',
      'Вересня',
      'Жовтня',
      'Листопада',
      'Грудня',
    ];
    return months[month - 1];
  }
}

class MapListingCard extends StatefulWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;

  const MapListingCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onTap,
  });

  @override
  State<MapListingCard> createState() => _MapListingCardState();
}

class _MapListingCardState extends State<MapListingCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<String> get _photos => widget.product.photos;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final hasPhotos = photos.isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (hasPhotos)
              PageView.builder(
                controller: _pageController,
                itemCount: photos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return CachedNetworkImage(
                    imageUrl: photos[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.image_not_supported,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          letterSpacing: 0.14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.product.formattedPrice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            '${widget.product.createdAt.day} ${_monthName(widget.product.createdAt.month)} '
                            '${widget.product.createdAt.hour}:${widget.product.createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              letterSpacing: 0.24,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.onFavoriteToggle,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(200),
                    border: Border.all(
                      color: const Color(0xFFF4F4F5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: widget.isFavorite
                        ? const Color(0xFF015873)
                        : const Color(0xFF27272A),
                  ),
                ),
              ),
            ),
            if (hasPhotos && photos.length > 1)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: ShapeDecoration(
                        color: Colors.black.withOpacity(0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Builder(
                        builder: (context) {
                          final total = photos.length;
                          int start = 0;
                          int count = total;
                          if (total > 3) {
                            if (_currentPage <= 0) {
                              start = 0;
                            } else if (_currentPage >= total - 1) {
                              start = total - 3;
                            } else {
                              start = _currentPage - 1;
                            }
                            count = 3;
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(count, (i) {
                              final dotIndex = start + i;
                              final isActive = dotIndex == _currentPage;
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? const Color(0xFF015873)
                                      : Colors.white.withOpacity(0.25),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Січня',
      'Лютого',
      'Березня',
      'Квітня',
      'Травня',
      'Червня',
      'Липня',
      'Серпня',
      'Вересня',
      'Жовтня',
      'Листопада',
      'Грудня',
    ];
    return months[month - 1];
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final ProductService _productService = ProductService();
  final MapController _mapController = MapController();
  final FilterManager _filterManager = FilterManager();
  List<Product> _products = [];
  List<Product> _productsWithLocation = [];
  bool _loading = true;
  String _searchQuery = '';
  final ProfileService _profileService = ProfileService();
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();

  void _goHome() {
    // Знайти GeneralPage в дереві і викликати зміну вкладки
    // Якщо GeneralPageState доступний через InheritedWidget або Provider, тут можна викликати callback
    // Для простоти: Navigator.of(context).pop() якщо MapPage відкрито через push
    // Якщо через таббар — можна використати callback або інший state management
    // Тут для прикладу: Navigator.of(context).popUntil((route) => route.isFirst);
    // Але для таббару краще передати callback
  }

  void _onFiltersChanged() {
    if (!mounted) return;
    final filters = _filterManager.currentFilters;
    final currentSearchQuery = filters['searchQuery'] as String? ?? '';
    setState(() {
      _searchQuery = currentSearchQuery;
      _searchController.text = currentSearchQuery;
    });
    _loadProducts();
  }

  @override
  void initState() {
    super.initState();
    final filters = _filterManager.currentFilters;
    final initialSearchQuery = filters['searchQuery'] as String? ?? '';
    _searchQuery = initialSearchQuery;
    _searchController.text = initialSearchQuery;
    _filterManager.addListener(_onFiltersChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    _filterManager.removeListener(_onFiltersChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _filterManager.updateFilter('searchQuery', value.isEmpty ? null : value);
      setState(() {
        _searchQuery = value;
        _products = [];
        _productsWithLocation = [];
        _loading = true;
      });
      _loadProducts();
    });
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final filters = _filterManager.currentFilters;
      final effectiveSearchQuery = _searchQuery.isNotEmpty
          ? _searchQuery
          : filters['searchQuery'];
      final products = await _productService.getProducts(
        searchQuery: effectiveSearchQuery,
        categoryId: filters['category'],
        subcategoryId: filters['subcategory'],
        region: filters['region'],
        minPrice: filters['minPrice'],
        maxPrice: filters['maxPrice'],
        isFree: filters['isFree'],
        minArea: filters['minArea'],
        maxArea: filters['maxArea'],
        minYear: filters['minYear'],
        maxYear: filters['maxYear'],
        brand: filters['car_brand'],
        size: filters['size'],
        condition: filters['condition'],
        jobType: filters['job_type'],
        conditionType: filters['condition_type'],
        radiusR: filters['radius_r'],
        genderType: filters['gender_type'],
        targetCurrency: filters['currency'],
        limit: 1000,
      );
      setState(() {
        _products = products;
        _productsWithLocation = products
            .where((p) => p.latitude != null && p.longitude != null)
            .toList();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToMarkers();
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _products = [];
        _productsWithLocation = [];
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToMarkers();
      });
    }
  }

  static final _ukraineBounds = LatLngBounds(
    LatLng(43.95, 21.65),
    LatLng(52.95, 40.65),
  );

  void _fitMapToMarkers() {
    final inUkraine = _productsWithLocation
        .where(
          (p) => _ukraineBounds.contains(LatLng(p.latitude!, p.longitude!)),
        )
        .toList();
    final toFit = inUkraine.isNotEmpty ? inUkraine : _productsWithLocation;

    if (toFit.isEmpty) {
      _mapController.move(LatLng(49.0, 32.0), 6.0);
      return;
    }

    if (toFit.length == 1) {
      final product = toFit.first;
      _mapController.move(LatLng(product.latitude!, product.longitude!), 13.0);
      return;
    }

    double minLat = toFit.first.latitude!;
    double maxLat = toFit.first.latitude!;
    double minLng = toFit.first.longitude!;
    double maxLng = toFit.first.longitude!;

    for (final product in toFit) {
      if (product.latitude! < minLat) minLat = product.latitude!;
      if (product.latitude! > maxLat) maxLat = product.latitude!;
      if (product.longitude! < minLng) minLng = product.longitude!;
      if (product.longitude! > maxLng) maxLng = product.longitude!;
    }

    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;

    final paddingKm = 100.0;
    final paddingDegrees = paddingKm / 111.0;

    final adjustedMinLat = minLat - paddingDegrees;
    final adjustedMaxLat = maxLat + paddingDegrees;
    final adjustedMinLng = minLng - paddingDegrees;
    final adjustedMaxLng = maxLng + paddingDegrees;

    final centerLat = (adjustedMinLat + adjustedMaxLat) / 2;
    final adjustedLatDiff = adjustedMaxLat - adjustedMinLat;
    final adjustedLngDiff = adjustedMaxLng - adjustedMinLng;
    final maxDiff = adjustedLatDiff > adjustedLngDiff
        ? adjustedLatDiff
        : adjustedLngDiff;

    double zoom;
    if (maxDiff > 10) {
      zoom = 5.5;
    } else if (maxDiff > 7) {
      zoom = 6.0;
    } else if (maxDiff > 5) {
      zoom = 6.5;
    } else if (maxDiff > 3) {
      zoom = 7.0;
    } else if (maxDiff > 2) {
      zoom = 7.5;
    } else if (maxDiff > 1) {
      zoom = 8.0;
    } else if (maxDiff > 0.5) {
      zoom = 9.0;
    } else if (maxDiff > 0.3) {
      zoom = 10.0;
    } else if (maxDiff > 0.15) {
      zoom = 11.0;
    } else if (maxDiff > 0.08) {
      zoom = 12.0;
    } else {
      zoom = 13.0;
    }

    final centerLng = (adjustedMinLng + adjustedMaxLng) / 2;

    _mapController.move(LatLng(centerLat, centerLng), zoom);
  }

  Future<void> _showFilterBottomSheet() async {
    final Map<String, dynamic>? newFilters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FilterPage(initialFilters: _filterManager.currentFilters),
      ),
    );
    if (newFilters != null) {
      _loadProducts();
    }
  }

  @override
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final markers = _productsWithLocation.map((product) {
      return Marker(
        width: 28,
        height: 32,
        point: LatLng(product.latitude!, product.longitude!),
        child: GestureDetector(
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              builder: (context) => Comments(products: [product]),
            );
          },
          child: const Pin(count: '1'),
        ),
      );
    }).toList();

    return wrapWithKeyboardDismisser(
      Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Карта на всю ширину і висоту
            Positioned.fill(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds(
                          LatLng(43.95, 21.65),
                          LatLng(52.95, 40.65),
                        ),
                        minZoom: 5.0,
                      ),
                      minZoom: 5.0,
                      maxZoom: 16.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const [],
                        userAgentPackageName: 'com.valtorian.zeno',
                      ),
                      if (!_loading && markers.isNotEmpty)
                        MarkerClusterLayerWidget(
                          key: ValueKey(
                            '${_productsWithLocation.length}_${_searchQuery}',
                          ),
                          options: MarkerClusterLayerOptions(
                            maxClusterRadius: 80,
                            maxZoom: 14,
                            size: const Size(40, 40),
                            markers: markers,
                            zoomToBoundsOnClick: false,
                            spiderfyCluster: false,
                            showPolygon: false,
                            builder: (context, markers) {
                              return Pin(count: markers.length.toString());
                            },
                            onClusterTap: (cluster) async {
                              final productsInCluster = cluster.markers
                                  .map(
                                    (m) => _productsWithLocation.firstWhere(
                                      (p) =>
                                          p.latitude == m.point.latitude &&
                                          p.longitude == m.point.longitude,
                                    ),
                                  )
                                  .toList();
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.7,
                                ),
                                builder: (context) =>
                                    Comments(products: productsInCluster),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  // Індикатор завантаження
                  if (_loading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Градієнтний overlay поверх карти
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.5, 0.0),
                    end: Alignment(0.5, 1.0),
                    colors: [
                      Color(0xFF015873), // 100%
                      Color(0x80015873), // 50%
                      Color(0x00015873), // 0%
                    ],
                  ),
                ),
              ),
            ),
            // Вміст хедера поверх градієнта
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                padding: const EdgeInsets.fromLTRB(13, 42, 13, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Лого
                    GestureDetector(
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      child: SvgPicture.asset(
                        'assets/icons/zeno-white.svg',
                        width: 101,
                        height: 24,
                      ),
                    ),
                    // Аватар користувача
                    Builder(
                      builder: (context) {
                        final user = Supabase.instance.client.auth.currentUser;
                        final avatarUrl =
                            user?.userMetadata?['avatar_url'] as String?;

                        return GestureDetector(
                          onTap: () {
                            if (user == null) {
                              // Показуємо bottom sheet для розлогінених користувачів
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: EdgeInsets.zero,
                                  child: Stack(
                                    children: [
                                      // Затемнення фону з блюром
                                      Positioned.fill(
                                        child: GestureDetector(
                                          onTap: () =>
                                              Navigator.of(context).pop(),
                                          child: ClipRect(
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 4,
                                                sigmaY: 4,
                                              ),
                                              child: Container(
                                                color: Colors.black.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Bottom sheet
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: AuthBottomSheet(
                                          title: 'Тут буде ваш профіль',
                                          subtitle:
                                              'Увійдіть у профіль, щоб керувати своїми даними та налаштуваннями.',
                                          onLoginPressed: () {
                                            Navigator.of(
                                              context,
                                            ).pop(); // Закриваємо bottom sheet
                                            Navigator.of(
                                              context,
                                            ).pushNamed('/auth');
                                          },
                                          onCancelPressed: () {
                                            Navigator.of(
                                              context,
                                            ).pop(); // Закриваємо bottom sheet
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              Navigator.pushNamed(context, '/profile');
                            }
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: avatarUrl == null
                                  ? Colors.grey[300]
                                  : null,
                            ),
                            child: avatarUrl == null
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Overlay-група: кнопка повернення + пошук/фільтр
            Positioned(
              top: 144, // 120px хедер + 24px відступ
              left: 13,
              right: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Кнопка повернення
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).maybePop();
                        },
                        child: SvgPicture.asset(
                          'assets/icons/chevron-states.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Головна',
                        style: TextStyle(
                          color: Color(0xFF161817),
                          fontSize: 28,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Пошук і фільтр
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(200),
                            border: Border.all(color: Color(0xFFE4E4E7)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF838583),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    hintText: 'Пошук оголошень...',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
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
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              color: Color(0xFF838583),
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              _filterManager.updateFilter(
                                                'searchQuery',
                                                null,
                                              );
                                              setState(() {
                                                _searchQuery = '';
                                                _products = [];
                                                _productsWithLocation = [];
                                                _loading = true;
                                              });
                                              _loadProducts();
                                            },
                                          )
                                        : _loading && _searchQuery.isNotEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF838583)),
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    height: 1.0,
                                  ),
                                  onChanged: (value) {
                                    _onSearchChanged(value);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _showFilterBottomSheet,
                        child: Builder(
                          builder: (context) {
                            final activeFiltersCount =
                                _filterManager.activeFiltersCount;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(200),
                                    border: Border.all(
                                      color: activeFiltersCount > 0
                                          ? const Color(0xFF015873)
                                          : const Color(0xFFE4E4E7),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.filter_alt_outlined,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Фільтр',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
