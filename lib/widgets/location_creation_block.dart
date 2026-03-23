import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:collection/collection.dart'; // NEW: Import for firstWhereOrNull

import 'dart:convert';
import 'dart:async';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LocationCreationBlock extends StatefulWidget {
  final Function(latlong.LatLng, String, String?, String?)?
  onLocationSelected; // Додано city parameter
  final latlong.LatLng? initialLocation;
  final String? initialRegion;
  final String? initialCity;

  const LocationCreationBlock({
    super.key,
    this.onLocationSelected,
    this.initialLocation,
    this.initialRegion,
    this.initialCity,
  });

  @override
  State<LocationCreationBlock> createState() => _LocationCreationBlockState();
}

class _LocationCreationBlockState extends State<LocationCreationBlock> {
  // Змінні для області
  String? _selectedRegion;
  bool _isRegionDropdownOpen = false;
  late final List<String> _regions;

  // Змінні для міста
  final TextEditingController _cityController = TextEditingController();
  List<Map<String, String>> _cityResults = [];
  bool _isSearchingCities = false;
  String? _selectedCity;
  String? _selectedPlaceId;
  Timer? _debounceTimer;

  // Змінні для повної адреси (вулиця, номер будинку)
  String? _selectedStreet;
  String? _selectedHouseNumber;
  String? _fullAddress;

  // Змінні для карти
  late final MapController _mapController;
  latlong.LatLng? _currentLocation;
  latlong.LatLng? _selectedLocation;
  bool _isLoadingLocation = false;
  final latlong.LatLng _ukraineCenter = const latlong.LatLng(49.0, 32.0);

  // Функція для правильного порівняння українських рядків
  int _compareUkrainianStrings(String a, String b) {
    // Мапа пріоритетів для українських літер (відповідно до алфавіту)
    final Map<String, int> ukrainianOrder = {
      'А': 1,
      'Б': 2,
      'В': 3,
      'Г': 4,
      'Ґ': 5,
      'Д': 6,
      'Е': 7,
      'Є': 8,
      'Ж': 9,
      'З': 10,
      'И': 11,
      'І': 12,
      'Ї': 13,
      'Й': 14,
      'К': 15,
      'Л': 16,
      'М': 17,
      'Н': 18,
      'О': 19,
      'П': 20,
      'Р': 21,
      'С': 22,
      'Т': 23,
      'У': 24,
      'Ф': 25,
      'Х': 26,
      'Ц': 27,
      'Ч': 28,
      'Ш': 29,
      'Щ': 30,
      'Ю': 31,
      'Я': 32,
      'а': 1,
      'б': 2,
      'в': 3,
      'г': 4,
      'ґ': 5,
      'д': 6,
      'е': 7,
      'є': 8,
      'ж': 9,
      'з': 10,
      'и': 11,
      'і': 12,
      'ї': 13,
      'й': 14,
      'к': 15,
      'л': 16,
      'м': 17,
      'н': 18,
      'о': 19,
      'п': 20,
      'р': 21,
      'с': 22,
      'т': 23,
      'у': 24,
      'ф': 25,
      'х': 26,
      'ц': 27,
      'ч': 28,
      'ш': 29,
      'щ': 30,
      'ю': 31,
      'я': 32,
    };

    final aLower = a.toLowerCase();
    final bLower = b.toLowerCase();
    final minLength = aLower.length < bLower.length
        ? aLower.length
        : bLower.length;

    for (int i = 0; i < minLength; i++) {
      final charA = aLower[i];
      final charB = bLower[i];

      final orderA = ukrainianOrder[charA] ?? charA.codeUnitAt(0);
      final orderB = ukrainianOrder[charB] ?? charB.codeUnitAt(0);

      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }
    }

    return aLower.length.compareTo(bLower.length);
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Ініціалізуємо та сортуємо області в алфавітному порядку
    final regionsList = [
      'Вінницька область',
      'Волинська область',
      'Дніпропетровська область',
      'Донецька область',
      'Житомирська область',
      'Закарпатська область',
      'Запорізька область',
      'Івано-Франківська область',
      'Київська область',
      'Кіровоградська область',
      'Луганська область',
      'Львівська область',
      'Миколаївська область',
      'Одеська область',
      'Полтавська область',
      'Рівненська область',
      'Сумська область',
      'Тернопільська область',
      'Харківська область',
      'Херсонська область',
      'Хмельницька область',
      'Черкаська область',
      'Чернівецька область',
      'Чернігівська область',
      'м. Київ',
      'м. Севастополь',
      'АР Крим',
    ];
    _regions = List.from(regionsList)
      ..sort((a, b) => _compareUkrainianStrings(a, b));

    _initializeData();
    _initializeMap();
  }

  void _initializeData() {
    if (widget.initialRegion != null) {
      _selectedRegion = widget.initialRegion;
    } else if (widget.initialCity != null) {
      // If no region, but city is provided, try to infer region from known regions
      final inferredRegion = _regions.firstWhereOrNull(
        (r) => widget.initialCity!.toLowerCase().contains(
          r.replaceAll(' область', '').replaceAll('м. ', '').toLowerCase(),
        ),
      );
      _selectedRegion =
          inferredRegion ?? 'Київська область'; // Default to a known region
    }

    if (widget.initialCity != null) {
      _selectedCity = widget.initialCity;
      _cityController.text = widget.initialCity!;
      print(
        'LocationCreationBlock: initialCity: ${widget.initialCity}, _cityController.text: ${_cityController.text}',
      ); // NEW: Logging
    }
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
    }
  }

  void _initializeMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedLocation != null) {
        _mapController.move(_selectedLocation!, 12.0);
      } else if (_selectedRegion != null) {
        _focusMapOnRegion(_selectedRegion!);
      } else {
        _mapController.move(_ukraineCenter, 6.0);
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isRegionDropdownOpen) {
          setState(() {
            _isRegionDropdownOpen = false;
          });
        }
      },
      child: Column(
        children: [
          // Верхня частина з полями вводу
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок "Локація"
              Text(
                'Локація',
                style: AppTextStyles.heading2Semibold.copyWith(
                  color: AppColors.color2,
                ),
              ),
              const SizedBox(height: 8),

              // Кнопка "Моє місцезнаходження" (переміщена вище)
              _buildLocationButton(),
              const SizedBox(height: 16),

              // Dropdown для вибору області
              _buildRegionDropdown(),
              const SizedBox(height: 16),

              // Поле вводу міста (показується тільки після вибору області)
              if (_selectedRegion != null) ...[
                _buildCityInput(),
                const SizedBox(height: 16),
              ],
            ],
          ),

          // Карта
          _buildMap(),
          const SizedBox(height: 8),
          // Підказка про вибір точки на карті
          Text(
            'Натисніть на карту, щоб вибрати точку локації',
            style: AppTextStyles.captionRegular.copyWith(
              color: AppColors.color8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Dropdown для вибору області
  Widget _buildRegionDropdown() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200),
          ),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isRegionDropdownOpen = !_isRegionDropdownOpen;
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedRegion ?? 'Оберіть область',
                    style: _selectedRegion != null
                        ? AppTextStyles.body1Regular.copyWith(
                            color: AppColors.color2,
                          )
                        : AppTextStyles.body1Regular.copyWith(
                            color: AppColors.color5,
                          ),
                  ),
                ),
                Icon(
                  _isRegionDropdownOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.color5,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_isRegionDropdownOpen)
          Container(
            width: double.infinity,
            height: 320,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(width: 1, color: const Color(0xFFEAECF0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x07101828),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: const Color(0x14101828),
                  blurRadius: 16,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _regions.length,
              itemBuilder: (context, index) {
                final region = _regions[index];
                final isSelected = _selectedRegion == region;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRegion = region;
                        _selectedCity = null;
                        _selectedPlaceId = null;
                        _cityController.clear();
                        _cityResults.clear();
                        _isRegionDropdownOpen = false;
                      });

                      if (region != null) {
                        _focusMapOnRegion(region);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 10,
                        left: 8,
                        right: 10,
                        bottom: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFAFAFA)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              region,
                              style: TextStyle(
                                color: const Color(0xFF0F1728),
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                height: 1.50,
                                letterSpacing: isSelected ? 0.16 : 0,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: Icon(
                                Icons.check,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // Поле вводу міста
  Widget _buildCityInput() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  textInputAction: TextInputAction.done,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Введіть назву міста або села',
                    hintStyle: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                  ),
                  onChanged: _onCitySearchChanged,
                ),
              ),
              if (_isSearchingCities)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (_cityResults.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: (_cityResults.length * 52.0).clamp(0, 200),
            ),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(width: 1, color: const Color(0xFFEAECF0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x07101828),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: const Color(0x14101828),
                  blurRadius: 16,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: _cityResults.length <= 4
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _cityResults.length,
              itemBuilder: (context, index) {
                final city = _cityResults[index];
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: GestureDetector(
                    onTap: () => _onCitySelected(city),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 10,
                        left: 8,
                        right: 10,
                        bottom: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _extractCityName(city['name'] ?? ''),
                              style: TextStyle(
                                color: const Color(0xFF0F1728),
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                height: 1.50,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // Карта
  Widget _buildMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Отримуємо ширину екрану
        final screenWidth = MediaQuery.of(context).size.width;

        // Розраховуємо розмір карти пропорційно
        // При ширині екрану 390px карта має бути 364x364
        final mapSize =
            (screenWidth - 32) * (364.0 / 358.0); // 358 = 390 - 32 (відступи)

        // Обмежуємо максимальний розмір
        final maxMapSize = screenWidth - 32;
        final finalMapSize = mapSize > maxMapSize ? maxMapSize : mapSize;

        // Обмежуємо висоту карти, щоб вона не була занадто великою
        final maxHeight = screenWidth * 0.8; // 80% від ширини екрану
        final finalHeight = finalMapSize > maxHeight ? maxHeight : finalMapSize;

        return Center(
          child: Container(
            width: finalMapSize,
            height: finalHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _selectedLocation ??
                          _currentLocation ??
                          _ukraineCenter,
                      initialZoom: _selectedLocation != null ? 12.0 : 6.0,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.pinchMove |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom,
                      ),
                      onTap: (tapPosition, point) {
                        FocusScope.of(context).unfocus();
                        _onMapTap(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const [],
                        userAgentPackageName: 'com.valtorian.zeno',
                      ),
                      if (_selectedLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40,
                              height: 40,
                              point: _selectedLocation!,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primaryColor,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Кнопки керування картою
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        _buildMapControlButton(
                          icon: Icons.add,
                          onTap: () {
                            try {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                currentZoom + 1,
                              );
                            } catch (e) {
                              // Error zooming in
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildMapControlButton(
                          icon: Icons.remove,
                          onTap: () {
                            try {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                currentZoom - 1,
                              );
                            } catch (e) {
                              // Error zooming out
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Кнопка керування картою
  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.zinc200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.color2),
      ),
    );
  }

  // Кнопка "Моє місцезнаходження"
  Widget _buildLocationButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5), // Zinc-100
        borderRadius: BorderRadius.circular(200),
        border: Border.all(
          width: 1,
          color: const Color(0xFFF4F4F5), // Zinc-100
        ),
      ),
      child: GestureDetector(
        onTap: _isLoadingLocation
            ? null
            : () {
                _getCurrentLocation();
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingLocation)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            else
              const SizedBox(
                width: 20,
                height: 20,
                child: Icon(Icons.my_location, color: Colors.black, size: 20),
              ),
            const SizedBox(width: 8),
            Text(
              'Моє місцезнаходження',
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
    );
  }

  // Методи для роботи з пошуком міст
  void _onCitySearchChanged(String query) {
    if (query.isEmpty || _selectedRegion == null) {
      setState(() {
        _cityResults.clear();
      });
      return;
    }

    // Debounce запитів
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearchingCities = true;
      });

      try {
        final results = await _searchCities(query, _selectedRegion!);
        setState(() {
          _cityResults = results;
          _isSearchingCities = false;
        });
      } catch (e) {
        setState(() {
          _cityResults.clear();
          _isSearchingCities = false;
        });
      }
    });
  }

  Future<List<Map<String, String>>> _searchCities(
    String query,
    String region,
  ) async {
    final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

    // Перевіряємо, чи користувач не вводить область, яка вже вибрана
    if (_isSameRegion(query, region)) {
      return [];
    }

    final url = Uri.parse(
      'https://wcczieoznbopcafdatpk.supabase.co/functions/v1/places-api'
      '?input=${Uri.encodeComponent(query)}'
      '&sessiontoken=$sessionToken'
      '&region=${Uri.encodeComponent(region)}'
      '&components=country:ua',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjY3ppZW96bmJvcGNhZmRhdHBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzNTc2MTEsImV4cCI6MjA2NjkzMzYxMX0.1OdLDVnzHx9ghZ7D8X2P_lpZ7XvnPtdEKN4ah_guUJ0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List<dynamic>;
          final cities = predictions.map<Map<String, String>>((p) {
            final Map<String, dynamic> prediction = p as Map<String, dynamic>;
            final description = prediction['description']?.toString() ?? '';
            final placeId = prediction['place_id']?.toString() ?? '';
            final city = {'name': description, 'placeId': placeId};
            final lat = prediction['lat'];
            final lng = prediction['lng'];
            if (lat != null && lng != null) {
              city['lat'] = lat.toString();
              city['lng'] = lng.toString();
            }
            return city;
          }).toList();

          return cities.where((city) {
            final name = city['name']?.toLowerCase() ?? '';
            final regionLower = region.toLowerCase();

            // Якщо ім'я є самою областю (напр. "Одеська область"), пропускаємо
            if (name == regionLower) {
              return false;
            }
            // Якщо це просто "Україна", теж пропускаємо
            if (name == 'україна' || name == 'ukraine') {
              return false;
            }

            // Залишаємо всі інші співпадіння, оскільки ми вже передали region в API запит
            // Це дозволить знаходити міста навіть якщо користувач ввів лише їх назву
            return true;
          }).toList();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка пошуку міст: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return [];
  }

  void _onCitySelected(Map<String, String> city) async {
    try {
      final cityName = _extractCityName(city['name'] ?? '');
      setState(() {
        _selectedCity = cityName;
        _selectedPlaceId = city['placeId'];
        _cityController.text = cityName;
        _cityResults.clear();
      });

      // Отримуємо координати міста та фокусуємо карту
      latlong.LatLng? coordinates;
      final latStr = city['lat'];
      final lngStr = city['lng'];
      if (latStr != null && lngStr != null) {
        final lat = double.tryParse(latStr);
        final lng = double.tryParse(lngStr);
        if (lat != null && lng != null) {
          coordinates = latlong.LatLng(lat, lng);
        }
      }
      if (city['placeId'] != null) {
        coordinates ??= await _getLatLngFromPlaceId(city['placeId']!);
      }
      if (coordinates != null) {
        setState(() {
          _selectedLocation = coordinates;
        });
        try {
          _mapController.move(coordinates, 12.0);
        } catch (e) {}
      }

      // Викликаємо callback з вибраною локацією
      if (widget.onLocationSelected != null && _selectedLocation != null) {
        final formattedAddress = _formatAddressForDisplay(
          _selectedCity,
          _selectedRegion,
        );
        widget.onLocationSelected!(
          _selectedLocation!,
          formattedAddress,
          _selectedRegion,
          _selectedCity,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка вибору міста: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Фокусування карти на області
  void _focusMapOnRegion(String region) {
    try {
      // Координати центрів областей України
      final regionCoordinates = {
        'Вінницька область': const latlong.LatLng(49.2331, 28.4682),
        'Волинська область': const latlong.LatLng(50.7476, 25.3253),
        'Дніпропетровська область': const latlong.LatLng(48.4647, 35.0462),
        'Донецька область': const latlong.LatLng(48.0159, 37.8028),
        'Житомирська область': const latlong.LatLng(50.2547, 28.6587),
        'Закарпатська область': const latlong.LatLng(48.6208, 22.2879),
        'Запорізька область': const latlong.LatLng(47.8388, 35.1396),
        'Івано-Франківська область': const latlong.LatLng(48.9226, 24.7111),
        'Київська область': const latlong.LatLng(50.4501, 30.5234),
        'Кіровоградська область': const latlong.LatLng(48.5079, 32.2623),
        'Луганська область': const latlong.LatLng(48.5740, 39.3078),
        'Львівська область': const latlong.LatLng(49.8397, 24.0297),
        'Миколаївська область': const latlong.LatLng(46.9750, 31.9946),
        'Одеська область': const latlong.LatLng(46.4825, 30.7233),
        'Полтавська область': const latlong.LatLng(49.5883, 34.5514),
        'Рівненська область': const latlong.LatLng(50.6199, 26.2516),
        'Сумська область': const latlong.LatLng(50.9077, 34.7981),
        'Тернопільська область': const latlong.LatLng(49.5535, 25.5948),
        'Харківська область': const latlong.LatLng(49.9935, 36.2304),
        'Херсонська область': const latlong.LatLng(46.6354, 32.6178),
        'Хмельницька область': const latlong.LatLng(49.4229, 26.9871),
        'Черкаська область': const latlong.LatLng(49.4444, 32.0598),
        'Чернівецька область': const latlong.LatLng(48.2917, 25.9352),
        'Чернігівська область': const latlong.LatLng(51.4982, 31.2893),
        'м. Київ': const latlong.LatLng(50.4501, 30.5234),
        'м. Севастополь': const latlong.LatLng(44.6166, 33.5254),
        'АР Крим': const latlong.LatLng(45.3453, 34.4997),
      };

      final coordinates = regionCoordinates[region] ?? _ukraineCenter;
      _mapController.move(coordinates, 8.0);
    } catch (e) {
      try {
        _mapController.move(_ukraineCenter, 6.0);
      } catch (e2) {
        // Error focusing on Ukraine center
      }
    }
  }

  // Отримання поточної локації
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Перевіряємо чи увімкнені сервіси геолокації
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Будь ласка, увімкніть GPS в налаштуваннях телефону',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Налаштування',
              onPressed: () async {
                await Geolocator.openLocationSettings();
              },
            ),
          ),
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _showLocationPermissionDeniedDialog();
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showLocationPermissionForeverDeniedDialog();
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Отримуємо поточну позицію
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best, // Змінено на найвищу точність
        timeLimit: const Duration(seconds: 15), // Збільшено таймаут
        forceAndroidLocationManager:
            false, // Використовуємо Google Play Services
      );

      // Перевіряємо точність позиції
      if (position.accuracy > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Увага: Низька точність геолокації (${position.accuracy.toStringAsFixed(1)}м). Перевірте налаштування GPS.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      final location = latlong.LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
        _selectedLocation = location;
        _isLoadingLocation = false;
      });

      // Фокусуємо карту на поточній локації з більшим zoom для точності
      try {
        _mapController.move(location, 16.0);
      } catch (e) {
        // Error focusing map
      }

      // Отримуємо адресу та заповнюємо поля
      await _fillLocationFromCoordinates(location);

      // Форматуємо повну адресу
      final formattedAddress = _formatFullAddress(
        _selectedStreet,
        _selectedHouseNumber,
        _selectedCity,
        _selectedRegion,
      );

      // Встановлюємо повну адресу в поле вводу (замість лише назви міста)
      setState(() {
        _cityController.text = formattedAddress.isNotEmpty
            ? formattedAddress
            : (_selectedCity ?? '');
      });

      // Викликаємо callback з вибраною локацією (з повною адресою)
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(
          location,
          formattedAddress,
          _selectedRegion,
          _selectedCity,
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка отримання локації: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showLocationPermissionDeniedDialog() {
    final content =
        'Для використання "Моє місцезнаходження" потрібен дозвіл. '
        'Будь ласка, надайте дозвіл для продовження.';
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoTheme(
          data: CupertinoThemeData(primaryColor: AppColors.primaryColor),
          child: CupertinoAlertDialog(
            title: const Text('Дозвіл на геолокацію'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(content, style: const TextStyle(fontSize: 13)),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Скасувати'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _getCurrentLocation();
                },
                child: const Text('Надати дозвіл'),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Дозвіл на геолокацію'),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Скасувати'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _getCurrentLocation();
              },
              child: const Text('Надати дозвіл'),
            ),
          ],
        ),
      );
    }
  }

  void _showLocationPermissionForeverDeniedDialog() {
    final content =
        'Дозвіл був відхилений назавжди. '
        'Увімкніть доступ до геолокації в налаштуваннях додатку.';
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoTheme(
          data: CupertinoThemeData(primaryColor: AppColors.primaryColor),
          child: CupertinoAlertDialog(
            title: const Text('Дозвіл на геолокацію'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(content, style: const TextStyle(fontSize: 13)),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Скасувати'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Geolocator.openAppSettings();
                },
                child: const Text('Налаштування'),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Дозвіл на геолокацію'),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Скасувати'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Налаштування'),
            ),
          ],
        ),
      );
    }
  }

  // Обробка тапу на карту для вибору точки
  Future<void> _onMapTap(latlong.LatLng point) async {
    print(
      'DEBUG (LocationCreationBlock): _onMapTap called with point: ${point.latitude}, ${point.longitude}',
    );

    setState(() {
      _selectedLocation = point;
    });

    // Збільшуємо zoom для кращої точності вибору (16-17 для вулиць)
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = currentZoom < 16.0 ? 16.0 : currentZoom;
    _mapController.move(point, targetZoom);

    // Отримуємо адресу за координатами (не фокусуємо на області, щоб не змінювати zoom)
    await _fillLocationFromCoordinates(point, shouldFocusOnRegion: false);

    print('DEBUG (LocationCreationBlock): After _fillLocationFromCoordinates:');
    print('  _selectedStreet: $_selectedStreet');
    print('  _selectedHouseNumber: $_selectedHouseNumber');
    print('  _selectedCity: $_selectedCity');
    print('  _selectedRegion: $_selectedRegion');

    // Форматуємо повну адресу для callback (включає вулицю та номер будинку)
    final formattedAddress = _formatFullAddress(
      _selectedStreet,
      _selectedHouseNumber,
      _selectedCity,
      _selectedRegion,
    );

    print(
      'DEBUG (LocationCreationBlock): Formatted full address: $formattedAddress',
    );

    // Встановлюємо повну адресу в поле вводу (замість лише назви міста)
    setState(() {
      _cityController.text = formattedAddress.isNotEmpty
          ? formattedAddress
          : (_selectedCity ?? '');
    });

    // Викликаємо callback з вибраною локацією
    if (widget.onLocationSelected != null) {
      print(
        'DEBUG (LocationCreationBlock): Calling onLocationSelected with address: $formattedAddress',
      );
      widget.onLocationSelected!(
        point,
        formattedAddress,
        _selectedRegion,
        _selectedCity,
      );
    }
  }

  // Заповнення полів з координат
  Future<void> _fillLocationFromCoordinates(
    latlong.LatLng location, {
    bool shouldFocusOnRegion = true,
  }) async {
    print(
      'DEBUG (LocationCreationBlock): _fillLocationFromCoordinates called with location: ${location.latitude}, ${location.longitude}',
    );

    try {
      // Використовуємо Nominatim OpenStreetMap API для Reverse Geocoding
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${location.latitude}&lon=${location.longitude}'
        '&format=json&accept-language=uk&addressdetails=1',
      );

      print('DEBUG (LocationCreationBlock): Requesting URL: $url');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'YourApp/1.0'},
      );

      print(
        'DEBUG (LocationCreationBlock): Response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG (LocationCreationBlock): Full API response: $data');

        final address = data['address'] as Map<String, dynamic>;
        print(
          'DEBUG (LocationCreationBlock): Address object from API: $address',
        );

        // Отримуємо область та місто з адреси
        String? region =
            address['state']?.toString() ??
            address['province']?.toString() ??
            address['region']?.toString();
        String? city =
            address['city']?.toString() ??
            address['town']?.toString() ??
            address['village']?.toString() ??
            address['municipality']?.toString();

        // Отримуємо вулицю та номер будинку для точної адреси
        String? street =
            address['road']?.toString() ??
            address['street']?.toString() ??
            address['pedestrian']?.toString();
        String? houseNumber =
            address['house_number']?.toString() ?? address['house']?.toString();

        print('DEBUG (LocationCreationBlock): Parsed values:');
        print(
          '  region (raw): ${address['state'] ?? address['province'] ?? address['region']}',
        );
        print(
          '  city (raw): ${address['city'] ?? address['town'] ?? address['village'] ?? address['municipality']}',
        );
        print(
          '  street (raw): ${address['road'] ?? address['street'] ?? address['pedestrian']}',
        );
        print(
          '  houseNumber (raw): ${address['house_number'] ?? address['house']}',
        );
        print('  Final region: $region');
        print('  Final city: $city');
        print('  Final street: $street');
        print('  Final houseNumber: $houseNumber');

        // Якщо місто не знайдено, беремо перший доступний населений пункт
        if (city == null) {
          city =
              address['suburb']?.toString() ??
              address['county']?.toString() ??
              address['district']?.toString();
        }

        // Якщо область не знайдено, беремо країну
        if (region == null) {
          region = address['country']?.toString();
        }

        // Виправляємо помилки API - перевіряємо відомі міста та їх області
        if (city != null) {
          final cityLower = city.toLowerCase();
          if (cityLower.contains('мукачево') ||
              cityLower.contains('mukachevo')) {
            region = 'Закарпатська область';
          } else if (cityLower.contains('київ') || cityLower.contains('kyiv')) {
            region = 'Київська область';
          } else if (cityLower.contains('львів') ||
              cityLower.contains('lviv')) {
            region = 'Львівська область';
          } else if (cityLower.contains('одеса') ||
              cityLower.contains('odessa')) {
            region = 'Одеська область';
          } else if (cityLower.contains('харків') ||
              cityLower.contains('kharkiv')) {
            region = 'Харківська область';
          } else if (cityLower.contains('дніпро') ||
              cityLower.contains('dnipro')) {
            region = 'Дніпропетровська область';
          }
        }

        // Форматуємо адресу для відображення
        final formattedAddress = _formatAddressForDisplay(city, region);

        // Перевіряємо, чи це Україна
        final country = address['country']?.toString();
        if (country == 'Україна' || country == 'Ukraine') {
          // Додаємо "область" до назви області, якщо її немає
          if (region != null && !region!.toLowerCase().contains('область')) {
            region = '$region область';
          }

          // Перевіряємо, чи область є в нашому списку
          if (region != null && _regions.contains(region!)) {
            print('DEBUG (LocationCreationBlock): Setting state with values:');
            print('  _selectedRegion: $region');
            print('  _selectedCity: $city');
            print('  _selectedStreet: $street');
            print('  _selectedHouseNumber: $houseNumber');

            setState(() {
              _selectedRegion = region!;
              _selectedCity = city;
              _selectedStreet = street;
              _selectedHouseNumber = houseNumber;
              _cityController.text =
                  city ?? ''; // NEW: Set city controller text to city name only
            });

            print('DEBUG (LocationCreationBlock): State updated successfully');

            // Фокусуємо карту на області тільки якщо потрібно (не при виборі точки на карті)
            if (shouldFocusOnRegion) {
              _focusMapOnRegion(region!);
            }
          } else {
            // Якщо область не знайдена в списку, встановлюємо за замовчуванням
            setState(() {
              _selectedRegion = 'Київська область';
              _selectedCity = city ?? 'Київ';
              _selectedStreet = street;
              _selectedHouseNumber = houseNumber;
              _cityController.text =
                  city ??
                  'Київ'; // NEW: Set city controller text to city name only
            });

            if (shouldFocusOnRegion) {
              _focusMapOnRegion('Київська область');
            }
          }
        } else {
          // Якщо це не Україна, встановлюємо за замовчуванням
          setState(() {
            _selectedRegion = 'Київська область';
            _selectedCity = 'Київ';
            _selectedStreet = street;
            _selectedHouseNumber = houseNumber;
            _cityController.text =
                'Київ'; // NEW: Set city controller text to city name only
          });

          if (shouldFocusOnRegion) {
            _focusMapOnRegion('Київська область');
          }
        }
      } else {
        throw Exception('Помилка отримання адреси: ${response.statusCode}');
      }
    } catch (e) {
      print('Помилка отримання адреси: $e');

      // При помилці встановлюємо за замовчуванням
      setState(() {
        _selectedRegion = 'Київська область';
        _selectedCity = 'Київ';
        _selectedStreet = null;
        _selectedHouseNumber = null;
        _cityController.text = _formatAddressForDisplay(
          'Київ',
          'Київська область',
        );
      });

      if (shouldFocusOnRegion) {
        _focusMapOnRegion('Київська область');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка отримання адреси: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Перевіряє, чи є частина адреси тією ж областю, що вже вибрана
  bool _isSameRegion(String addressPart, String selectedRegion) {
    final partLower = addressPart.toLowerCase();
    final regionLower = selectedRegion.toLowerCase();

    // Пряме порівняння
    if (partLower == regionLower) {
      return true;
    }

    // Порівняння без "область" та "м."
    final cleanPart = partLower
        .replaceAll('область', '')
        .replaceAll('м.', '')
        .trim();
    final cleanRegion = regionLower
        .replaceAll('область', '')
        .replaceAll('м.', '')
        .trim();

    if (cleanPart == cleanRegion) {
      return true;
    }

    // Перевіряємо, чи містить частина адреси назву області
    if (partLower.contains('область') && regionLower.contains('область')) {
      // Видаляємо слово "область" та порівнюємо
      final partWithoutRegion = partLower.replaceAll('область', '').trim();
      final regionWithoutRegion = regionLower.replaceAll('область', '').trim();
      if (partWithoutRegion == regionWithoutRegion) {
        return true;
      }
    }

    // Перевіряємо міста-області (Київ, Севастополь)
    if (regionLower.contains('м. київ') && partLower.contains('київ')) {
      return true;
    }
    if (regionLower.contains('м. севастополь') &&
        partLower.contains('севастополь')) {
      return true;
    }

    return false;
  }

  // Отримання координат з Place ID
  Future<latlong.LatLng?> _getLatLngFromPlaceId(String placeId) async {
    final url = Uri.parse(
      'https://wcczieoznbopcafdatpk.supabase.co/functions/v1/places-api?place_id=$placeId',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjY3ppZW96bmJvcGNhZmRhdHBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzNTc2MTEsImV4cCI6MjA2NjkzMzYxMX0.1OdLDVnzHx9ghZ7D8X2P_lpZ7XvnPtdEKN4ah_guUJ0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>;
          final location = geometry['location'] as Map<String, dynamic>;
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;
          return latlong.LatLng(lat, lng);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка отримання координат: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return null;
  }

  String _extractCityName(String fullAddress) {
    final first = fullAddress.split(',').first.trim();
    return first.isEmpty ? fullAddress : first;
  }

  String _formatAddressForDisplay(String? city, String? region) {
    // Налаштування відображення адреси
    final bool showCity = true; // Показувати місто
    final bool showRegion = false; // НЕ показувати область
    final bool showCountry = false; // НЕ показувати країну

    final List<String> parts = [];

    if (showCity && city != null && city.isNotEmpty) {
      parts.add(city);
    }

    return parts.join(', ');
  }

  // Форматування повної адреси з вулицею та номером будинку
  String _formatFullAddress(
    String? street,
    String? houseNumber,
    String? city,
    String? region,
  ) {
    print('DEBUG (LocationCreationBlock): _formatFullAddress called with:');
    print('  street: $street');
    print('  houseNumber: $houseNumber');
    print('  city: $city');
    print('  region: $region');

    final List<String> parts = [];

    // Додаємо вулицю та номер будинку (якщо є)
    if (street != null && street.isNotEmpty) {
      if (houseNumber != null && houseNumber.isNotEmpty) {
        parts.add('$street, $houseNumber');
        print(
          'DEBUG (LocationCreationBlock): Added street with house number: $street, $houseNumber',
        );
      } else {
        parts.add(street);
        print(
          'DEBUG (LocationCreationBlock): Added street without house number: $street',
        );
      }
    } else {
      print('DEBUG (LocationCreationBlock): No street found');
    }

    // Додаємо місто
    if (city != null && city.isNotEmpty) {
      parts.add(city);
      print('DEBUG (LocationCreationBlock): Added city: $city');
    } else {
      print('DEBUG (LocationCreationBlock): No city found');
    }

    // Додаємо область (опціонально)
    if (region != null && region.isNotEmpty) {
      parts.add(region);
      print('DEBUG (LocationCreationBlock): Added region: $region');
    }

    final result = parts.isNotEmpty ? parts.join(', ') : 'Обрана локація';
    print('DEBUG (LocationCreationBlock): Final formatted address: $result');

    return result;
  }
}
