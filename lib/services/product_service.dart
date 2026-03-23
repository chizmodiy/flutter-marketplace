import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import 'exchange_rate_service.dart'; // Import ExchangeRateService

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;

  final ExchangeRateService _exchangeRateService = ExchangeRateService(
    Supabase.instance.client,
  ); // Initialize ExchangeRateService
  Map<String, double>?
  _exchangeRatesMap; // Declare _exchangeRatesMap as nullable

  ProductService() {
    _loadExchangeRates(); // Load exchange rates in the constructor
  }

  Future<void> _loadExchangeRates() async {
    try {
      final rates = await _exchangeRateService.fetchExchangeRates();
      _exchangeRatesMap = {
        for (var rate in rates) rate.currencyCode: rate.rateToUah,
      };
      if (!_exchangeRatesMap!.containsKey('UAH')) {
        _exchangeRatesMap!['UAH'] = 1.0; // Ensure UAH is always present
      }
    } catch (e) {
      _exchangeRatesMap = {
        'USD': 38.0,
        'EUR': 41.0,
        'UAH': 1.0,
      }; // Default rates on error
    }
  }

  Future<Product> getProductById(String id, {String? targetCurrency}) async {
    if (_exchangeRatesMap == null) {
      await _loadExchangeRates(); // Ensure rates are loaded before use
    }
    try {
      final response = await _supabase
          .from('listings')
          .select(
            '*, categories!id(name), subcategories!id(name)',
          ) // Fetch category and subcategory names
          .eq('id', id)
          .single();

      final categoryName =
          (response['categories'] as Map<String, dynamic>)['name'] as String?;
      final subcategoryName =
          (response['subcategories'] as Map<String, dynamic>)['name']
              as String?;

      final product = Product.fromJson({
        ...response,
        'category_name': categoryName,
        'subcategory_name': subcategoryName,
      });

      // Apply currency conversion if targetCurrency is provided
      if (targetCurrency != null &&
          product.price != null &&
          product.currency != null &&
          product.currency!.toLowerCase() != targetCurrency.toLowerCase()) {
        final originalRate =
            _exchangeRatesMap![product.currency!.toUpperCase()] ?? 1.0;
        final targetRate =
            _exchangeRatesMap![targetCurrency.toUpperCase()] ?? 1.0;
        if (originalRate != 0 && targetRate != 0) {
          final priceInUAH = product.price! * originalRate;
          final convertedPrice = priceInUAH / targetRate;
          return product.copyWith(
            displayPrice: convertedPrice,
            displayCurrency: targetCurrency,
          );
        }
      }
      return product.copyWith(
        displayPrice: product.price,
        displayCurrency: product.currency,
      ); // Return original price/currency if no conversion or target is UAH/null
    } catch (e) {
      throw Exception('Помилка завантаження товару: $e');
    }
  }

  Future<List<Product>> getProductsByIds(
    List<String> productIds, {
    String? targetCurrency,
  }) async {
    if (productIds.isEmpty) {
      return [];
    }
    try {
      final response = await _supabase
          .from('listings')
          .select()
          .in_('id', productIds)
          .or(
            'status.is.null,status.eq.active',
          ); // Фільтруємо тільки активні оголошення

      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Apply currency conversion to each product
      if (targetCurrency != null) {
        return products.map((product) {
          if (product.price != null &&
              product.currency != null &&
              product.currency!.toLowerCase() != targetCurrency.toLowerCase()) {
            final originalRate =
                _exchangeRatesMap![product.currency!.toUpperCase()] ?? 1.0;
            final targetRate =
                _exchangeRatesMap![targetCurrency.toUpperCase()] ?? 1.0;
            if (originalRate != 0 && targetRate != 0) {
              final priceInUAH = product.price! * originalRate;
              final convertedPrice = priceInUAH / targetRate;
              return product.copyWith(
                displayPrice: convertedPrice,
                displayCurrency: targetCurrency,
              );
            }
          }
          return product.copyWith(
            displayPrice: product.price,
            displayCurrency: product.currency,
          );
        }).toList();
      }
      return products
          .map(
            (product) => product.copyWith(
              displayPrice: product.price,
              displayCurrency: product.currency,
            ),
          )
          .toList(); // Return with original prices and currencies if no targetCurrency
    } catch (e) {
      return [];
    }
  }

  Future<List<Product>> getSimilarProducts({
    required String categoryId,
    required String excludeProductId,
    int limit = 10,
  }) async {
    if (_exchangeRatesMap == null) {
      await _loadExchangeRates();
    }
    try {
      final response = await _supabase
          .from('listings')
          .select()
          .eq('category_id', categoryId)
          .neq('id', excludeProductId)
          .or('status.is.null,status.eq.active')
          .order('created_at', ascending: false)
          .limit(limit);

      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
      return products
          .map(
            (product) => product.copyWith(
              displayPrice: product.price,
              displayCurrency: product.currency,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Новий метод для отримання всіх оголошень користувача (включаючи неактивні)
  Future<List<Product>> getUserProducts(
    String userId, {
    String? targetCurrency,
  }) async {
    if (_exchangeRatesMap == null) {
      await _loadExchangeRates(); // Ensure rates are loaded before use
    }
    try {
      final response = await _supabase
          .from('listings')
          .select(
            '*, categories!id(name), subcategories!id(name)',
          ) // Fetch category and subcategory names
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Apply currency conversion to each product
      final effectiveTargetCurrency =
          targetCurrency ?? 'UAH'; // Default to UAH if not specified
      return products.map((product) {
        if (product.price != null &&
            product.currency != null &&
            product.currency!.toLowerCase() !=
                effectiveTargetCurrency.toLowerCase()) {
          final originalRate =
              _exchangeRatesMap![product.currency!.toUpperCase()] ?? 1.0;
          final targetRate =
              _exchangeRatesMap![effectiveTargetCurrency.toUpperCase()] ?? 1.0;
          if (originalRate != 0 && targetRate != 0) {
            final priceInUAH = product.price! * originalRate;
            final convertedPrice = priceInUAH / targetRate;
            return product.copyWith(
              displayPrice: convertedPrice,
              displayCurrency: effectiveTargetCurrency,
            );
          }
        }
        return product.copyWith(
          displayPrice: product.price,
          displayCurrency: product.currency,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Метод для отримання одного оголошення з детальною інформацією
  Future<Product?> getProductByIdWithDetails(String productId) async {
    try {
      final response = await _supabase
          .from('listings')
          .select()
          .eq('id', productId)
          .single();

      final product = Product.fromJson(response);
      return product;
    } catch (e) {
      return null;
    }
  }

  // NEW PUBLIC METHOD: Convert price from given currency to UAH
  double convertToUAH(double price, String currencyCode) {
    final rate = _exchangeRatesMap![currencyCode.toUpperCase()] ?? 1.0;
    return price * rate;
  }

  // NEW PUBLIC METHOD: Convert price from UAH to given target currency
  double convertFromUAH(double price, String targetCurrencyCode) {
    final rate = _exchangeRatesMap![targetCurrencyCode.toUpperCase()] ?? 1.0;
    if (rate == 0.0) return price; // Avoid division by zero
    return price / rate;
  }

  // NEW METHOD: Get global min/max price for a given currency column from the database
  Future<Map<String, double>> getGlobalMinMaxPrice(String currencyCode) async {
    String priceColumn;
    switch (currencyCode.toLowerCase()) {
      case 'uah':
        priceColumn = 'price_in_uah';
        break;
      case 'usd':
        priceColumn = 'price_in_usd';
        break;
      case 'eur':
        priceColumn = 'price_in_eur';
        break;
      default:
        priceColumn = 'price_in_uah'; // Default to UAH
        break;
    }

    try {
      final response = await _supabase
          .rpc(
            'get_min_max_price_by_currency_column',
            params: {'currency_price_column': priceColumn},
          )
          .single();

      if (response != null) {
        final minPrice = (response['min'] as num?)?.toDouble() ?? 0.0;
        final maxPrice = (response['max'] as num?)?.toDouble() ?? 100000.0;
        return {'min': minPrice, 'max': maxPrice};
      }
    } catch (e) {
      print('Error fetching global min/max price for $currencyCode: $e');
    }
    return {'min': 0.0, 'max': 100000.0};
  }

  Future<List<Product>> getProducts({
    int limit = 10,
    int offset = 0,
    String? searchQuery,
    String? categoryId,
    String? subcategoryId,
    dynamic region, // Accepts either String or List<String>
    double? minPrice,
    double? maxPrice,
    bool? hasDelivery,
    String? sortBy,
    bool? isFree,
    double? minArea,
    double? maxArea,
    int? minYear,
    int? maxYear,
    String? brand,
    double? minMileage,
    double? maxMileage,
    String? size,
    String? condition,
    String? targetCurrency,
    String? conditionType,
    String? giveawayType,
    String? jobType,
    double? radiusR,
    String? genderType,
    String? realEstateType,
    String? makeId,
    String? modelId,
    String? styleId,
    String? modelYearId,
    int? minCarYear,
    int? maxCarYear,
  }) async {
    try {
      dynamic query = _supabase.from('listings').select('*');

      // Логування параметрів фільтрації
      print('ProductService.getProducts: targetCurrency = $targetCurrency');
      print('ProductService.getProducts: minPrice = $minPrice');
      print('ProductService.getProducts: maxPrice = $maxPrice');

      // Apply filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('title', '%$searchQuery%');
      }

      // Apply sorting
      if (sortBy == 'random') {
        // Get more items than needed for better randomization
        // Apply offset to avoid fetching the same first N records on every page
        // then shuffle client-side to keep a "random" feel while respecting pagination.
        query = query
            .order('created_at', ascending: true)
            .range(offset, offset + (limit * 3) - 1);
        final response = await query;
        final List<dynamic> data = response as List<dynamic>;
        print(
          'ProductService.getProducts (random): Raw response length: ${data.length}',
        );
        final products = data.map((json) => Product.fromJson(json)).toList();
        print(
          'ProductService.getProducts (random): Parsed products length: ${products.length}',
        );
        products.shuffle(); // Shuffle the results

        // Apply currency conversion to each product
        print(
          'ProductService.getProducts (random): Before currency conversion: ${products.length} products',
        );
        print(
          'ProductService.getProducts (random): _exchangeRatesMap is null: ${_exchangeRatesMap == null}',
        );
        if (_exchangeRatesMap != null) {
          print(
            'ProductService.getProducts (random): _exchangeRatesMap keys: ${_exchangeRatesMap!.keys.toList()}',
          );
        }
        final convertedProducts = products
            .map((product) {
              print(
                'ProductService.getProducts (random): Processing product ID: ${product.id}, Price: ${product.price}, Currency: ${product.currency}',
              );
              if (targetCurrency != null &&
                  product.price != null &&
                  product.currency != null &&
                  product.currency!.toLowerCase() !=
                      targetCurrency.toLowerCase()) {
                final originalRate =
                    _exchangeRatesMap![product.currency!.toUpperCase()] ?? 1.0;
                final targetRate =
                    _exchangeRatesMap![targetCurrency.toUpperCase()] ?? 1.0;
                print(
                  'ProductService.getProducts (random): Currency conversion - originalRate: $originalRate, targetRate: $targetRate',
                );
                if (originalRate != 0 && targetRate != 0) {
                  final priceInUAH = product.price! * originalRate;
                  final convertedPrice = priceInUAH / targetRate;
                  print(
                    'ProductService.getProducts (random): Converted price: $convertedPrice',
                  );
                  return product.copyWith(
                    displayPrice: convertedPrice,
                    displayCurrency: targetCurrency,
                  );
                }
              }
              print(
                'ProductService.getProducts (random): No conversion needed, returning original product',
              );
              return product.copyWith(
                displayPrice: product.price,
                displayCurrency: product.currency,
              );
            })
            .take(limit)
            .toList(); // Повертаємо тільки потрібну кількість товарів
        print(
          'ProductService.getProducts (random): After currency conversion: ${convertedProducts.length} products',
        );
        print('ProductService.getProducts (random): Limit was: $limit');
        return convertedProducts;
      } else {
        // Apply normal sorting
        switch (sortBy) {
          case 'price_asc':
            query = query.order('price', ascending: true);
            break;
          case 'price_desc':
            query = query.order('price', ascending: false);
            break;
          default:
            query = query.order('created_at', ascending: false);
        }

        if (minCarYear != null || maxCarYear != null) {
          try {
            var modelYearsQuery = _supabase.from('model_years').select('id');
            if (styleId != null) {
              modelYearsQuery = modelYearsQuery.eq('style_id', styleId);
            } else if (modelId != null) {
              final stylesResponse = await _supabase
                  .from('styles')
                  .select('id')
                  .eq('model_id', modelId);
              final styleIds =
                  stylesResponse != null && stylesResponse.isNotEmpty
                  ? (stylesResponse as List)
                        .map((s) => s['id'] as String)
                        .toList()
                  : <String>[];
              if (styleIds.isNotEmpty) {
                modelYearsQuery = modelYearsQuery.in_('style_id', styleIds);
              } else {
                modelYearsQuery = modelYearsQuery.eq(
                  'id',
                  '00000000-0000-0000-0000-000000000000',
                );
              }
            }
            if (minCarYear != null) {
              modelYearsQuery = modelYearsQuery.gte('year', minCarYear);
            }
            if (maxCarYear != null) {
              modelYearsQuery = modelYearsQuery.lte('year', maxCarYear);
            }
            final modelYearsResponse = await modelYearsQuery;
            if (modelYearsResponse != null && modelYearsResponse.isNotEmpty) {
              final modelYearIds = (modelYearsResponse as List)
                  .map((my) => my['id'] as String)
                  .toList();
              query = query.in_('model_year_id', modelYearIds);
            } else if (modelYearsResponse != null &&
                modelYearsResponse.isEmpty) {
              query = query.eq('id', '00000000-0000-0000-0000-000000000000');
            }
          } catch (e) {
            print('Error filtering by car year range: $e');
          }
        }

        // Apply pagination
        query = query.range(offset, offset + limit - 1);

        // Apply other filters using the helper method
        query = _applyFilters(
          query,
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          region: region,
          minPrice: minPrice,
          maxPrice: maxPrice,
          hasDelivery: hasDelivery,
          isFree: isFree,
          minArea: minArea,
          maxArea: maxArea,
          minYear: minYear?.toDouble(),
          maxYear: maxYear?.toDouble(),
          brand: brand,
          minMileage: minMileage,
          maxMileage: maxMileage,
          size: size,
          condition: condition,
          targetCurrency: targetCurrency, // NEW: Передаємо targetCurrency
          conditionType: conditionType,
          giveawayType: giveawayType,
          jobType: jobType,
          radiusR: radiusR,
          genderType: genderType,
          realEstateType: realEstateType,
          makeId: makeId,
          modelId: modelId,
          styleId: styleId,
          modelYearId: modelYearId,
        );

        final response = await query;
        final List<dynamic> data = response as List<dynamic>;
        print(
          'ProductService.getProducts: Raw response length: ${data.length}',
        );
        final products = data.map((json) => Product.fromJson(json)).toList();
        print(
          'ProductService.getProducts: Parsed products length: ${products.length}',
        );

        // Логуємо ціни отриманих продуктів
        products.forEach((product) {
          print(
            'ProductService.getProducts: Product ID: ${product.id}, Original Price: ${product.price}, Original Currency: ${product.currency}, Price in UAH: ${product.priceInUah}, Price in USD: ${product.priceInUsd}, Price in EUR: ${product.priceInEur}',
          );
        });

        // Apply currency conversion to each product
        return products.map((product) {
          if (targetCurrency != null &&
              product.price != null &&
              product.currency != null &&
              product.currency!.toLowerCase() != targetCurrency.toLowerCase()) {
            final originalRate =
                _exchangeRatesMap![product.currency!.toUpperCase()] ?? 1.0;
            final targetRate =
                _exchangeRatesMap![targetCurrency.toUpperCase()] ?? 1.0;
            if (originalRate != 0 && targetRate != 0) {
              final priceInUAH = product.price! * originalRate;
              final convertedPrice = priceInUAH / targetRate;
              return product.copyWith(
                displayPrice: convertedPrice,
                displayCurrency: targetCurrency,
              );
            }
          }
          return product.copyWith(
            displayPrice: product.price,
            displayCurrency: product.currency,
          );
        }).toList();
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<Product>> getAllProductsWithCoordinates() async {
    try {
      final response = await _supabase
          .from('listings')
          .select()
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .or(
            'status.is.null,status.eq.active',
          ); // Фільтруємо тільки активні оголошення
      return (response as List).map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateProduct({
    required String id,
    required String title,
    String? description,
    required String categoryId,
    required String subcategoryId,
    required String location,
    required bool isFree,
    String? currency,
    double? price,
    String? phoneNumber,
    String? whatsapp,
    String? telegram,
    String? viber,
    String? address,
    String? region,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? customAttributes,
  }) async {
    try {
      await _supabase
          .from('listings')
          .update({
            'title': title,
            'description': description,
            'category_id': categoryId,
            'subcategory_id': subcategoryId,
            'location': location,
            'is_free': isFree,
            'currency': currency,
            'price': price,
            'phone_number': phoneNumber,
            'whatsapp': whatsapp,
            'telegram': telegram,
            'viber': viber,
            'address': address,
            'region': region,
            'latitude': latitude,
            'longitude': longitude,
            'custom_attributes': customAttributes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Помилка оновлення товару: $e');
    }
  }

  // Покращений метод застосування фільтрів
  PostgrestFilterBuilder _applyFilters(
    PostgrestFilterBuilder query, {
    String? categoryId,
    String? subcategoryId,
    dynamic region,
    double? minPrice,
    double? maxPrice,
    bool? hasDelivery,
    bool? isFree,
    double? minArea,
    double? maxArea,
    double? minYear,
    double? maxYear,
    String? brand,
    double? minMileage,
    double? maxMileage,
    String? size,
    String? condition,
    String? targetCurrency, // NEW: Додаємо targetCurrency
    String? conditionType,
    String? giveawayType,
    String? jobType,
    double? radiusR,
    String? genderType,
    String? realEstateType,
    String? makeId,
    String? modelId,
    String? styleId,
    String? modelYearId,
    int? minCarYear,
    int? maxCarYear,
  }) {
    // Категорія
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      query = query.eq('category_id', categoryId);
    }

    // Підкатегорія
    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      query = query.eq('subcategory_id', subcategoryId);
    }

    // Регіон
    if (region != null) {
      if (region is List && region.isNotEmpty) {
        final regionConditions = region.map((r) => 'region.ilike.%$r%,location.ilike.%$r%').join(',');
        query = query.or(regionConditions);
      } else if (region is String && region.isNotEmpty) {
        query = query.or('region.ilike.%$region%,location.ilike.%$region%');
      }
    }

    // Валюта - ВАЖЛИВО: фільтруємо за конкретною валютою
    // if (currency != null && currency.isNotEmpty) {
    //   query = query.eq('currency', currency);
    // }

    // Безкоштовні оголошення
    if (isFree == true) {
      query = query.eq('is_free', true);
    } else {
      // Ціни - фільтруємо в межах вибраної валюти
      String priceColumnToFilter = 'price_in_uah'; // За замовчуванням
      if (targetCurrency != null) {
        switch (targetCurrency.toLowerCase()) {
          case 'uah':
            priceColumnToFilter = 'price_in_uah';
            break;
          case 'usd':
            priceColumnToFilter = 'price_in_usd';
            break;
          case 'eur':
            priceColumnToFilter = 'price_in_eur';
            break;
        }
      }

      print(
        'ProductService._applyFilters: Using priceColumnToFilter = $priceColumnToFilter',
      );

      double effectiveMinPrice =
          minPrice ??
          0.0; // За замовчуванням minPrice з FilterManager завжди в UAH
      double effectiveMaxPrice =
          maxPrice ??
          100000.0; // За замовчуванням maxPrice з FilterManager завжди в UAH

      // Якщо фільтруємо за іншою валютою, конвертуємо ціни з UAH у потрібну валюту
      if (targetCurrency != null && targetCurrency.toLowerCase() != 'uah') {
        effectiveMinPrice = convertFromUAH(effectiveMinPrice, targetCurrency);
        effectiveMaxPrice = convertFromUAH(effectiveMaxPrice, targetCurrency);
        print(
          'ProductService._applyFilters: Converted minPrice to $targetCurrency = $effectiveMinPrice',
        );
        print(
          'ProductService._applyFilters: Converted maxPrice to $targetCurrency = $effectiveMaxPrice',
        );
      }

      if (minPrice != null && minPrice >= 0) {
        query = query.gte(priceColumnToFilter, effectiveMinPrice);
        print(
          'ProductService._applyFilters: Applying GTE $priceColumnToFilter with value $effectiveMinPrice',
        );
      }

      if (maxPrice != null && maxPrice >= 0 && maxPrice < 999999999) {
        query = query.lte(priceColumnToFilter, effectiveMaxPrice);
        print(
          'ProductService._applyFilters: Applying LTE $priceColumnToFilter with value $effectiveMaxPrice',
        );
      }
    }

    // Доставка
    if (hasDelivery != null) {
      query = query.eq('has_delivery', hasDelivery);
    }

    // Площа
    if (minArea != null && minArea > 0) {
      query = query.gte('custom_attributes->area', minArea);
    }
    if (maxArea != null && maxArea > 0 && maxArea < 10000) {
      query = query.lte('custom_attributes->area', maxArea);
    }

    // Рік
    if (minYear != null && minYear > 1900) {
      query = query.gte('custom_attributes->year', minYear);
    }
    if (maxYear != null && maxYear <= DateTime.now().year + 1) {
      query = query.lte('custom_attributes->year', maxYear);
    }

    // Бренд авто
    if (brand != null && brand.isNotEmpty) {
      query = query.eq('custom_attributes->car_brand', brand);
    }

    // Пробіг
    if (minMileage != null) {
      query = query.gte('mileage_thousands_km', minMileage);
    }
    if (maxMileage != null) {
      query = query.lte('mileage_thousands_km', maxMileage);
    }

    // Розмір
    if (size != null && size.isNotEmpty) {
      query = query.eq('custom_attributes->>size', size);
    }

    // Стан
    if (condition != null && condition.isNotEmpty) {
      query = query.eq('custom_attributes->condition', condition);
    }

    if (conditionType != null && conditionType.isNotEmpty) {
      query = query.eq('condition_type', conditionType);
    }

    if (giveawayType != null && giveawayType.isNotEmpty) {
      query = query.eq('custom_attributes->giveaway_type', giveawayType);
    }

    if (jobType != null && jobType.isNotEmpty) {
      query = query.eq('job_type', jobType);
    }

    if (radiusR != null && radiusR > 0) {
      query = query.eq('radius_r', radiusR);
    }

    if (genderType != null && genderType != 'both') {
      query = query.eq('gender_type', genderType);
    }

    if (realEstateType != null) {
      query = query.eq('real_estate_type', realEstateType);
    }

    // Нові фільтри для легкових авто та авто з Польщі
    if (makeId != null && makeId.isNotEmpty) {
      query = query.eq('make_id', makeId);
    }

    if (modelId != null && modelId.isNotEmpty) {
      query = query.eq('model_id', modelId);
    }

    if (styleId != null && styleId.isNotEmpty) {
      query = query.eq('style_id', styleId);
    }

    if (modelYearId != null && modelYearId.isNotEmpty) {
      query = query.eq('model_year_id', modelYearId);
    }

    return query;
  }
}
