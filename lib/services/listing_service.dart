import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'storage_service.dart';
import 'exchange_rate_service.dart'; // Import ExchangeRateService

import '../models/listing.dart'; // Added this import

enum CurrencyEnum { uah, eur, usd }

class ListingService {
  final SupabaseClient _client;
  late final StorageService _storageService;
  late final ExchangeRateService
  _exchangeRateService; // Declare ExchangeRateService

  ListingService(this._client) {
    _storageService = StorageService(_client);
    _exchangeRateService = ExchangeRateService(
      _client,
    ); // Initialize ExchangeRateService
  }

  Future<String> createListing({
    required String title,
    required String description,
    required String categoryId,
    required String subcategoryId,
    String? location,
    required bool isFree,
    String? currency,
    double? price,
    bool? isNegotiable,
    String? phoneNumber,
    String? whatsapp,
    String? telegram,
    String? viber,
    String? address,
    String? region,
    double? latitude,
    double? longitude,
    required Map<String, dynamic> customAttributes,
    required List<XFile> images,
    String? realEstateType,
    double? mileageThousands,
    String? jobType,
    String? helpType,
    String? giveawayType,
    String? conditionType,
    String? size,
    double? radiusR,
    String? genderType,
    String? makeId,
    String? modelId,
    String? styleId,
    String? modelYearId,
  }) async {
    try {
      // Validate price and currency based on isFree and isNegotiable
      late double? originalPriceInUAH; // Declare here
      late String? originalCurrency; // Declare here

      if (isFree) {
        if (price != null && price > 0) {
          throw Exception('Free listings cannot have a positive price');
        }
        // Allow null currency and null price for free listings
        originalPriceInUAH =
            null; // For free listings, original price in UAH is null
        originalCurrency = null; // For free listings, no currency
      } else {
        if (isNegotiable == true) {
          // For negotiable listings, price can be null or any valid price
          if (price != null && price < 0) {
            throw Exception('Price cannot be negative');
          }
          // Set originalCurrency for negotiable listings
          originalCurrency = currency;
          if (price != null && currency != null) {
            // Convert price to UAH if currency is not UAH
            if (currency.toLowerCase() != 'uah') {
              final exchangeRates = await _exchangeRateService
                  .fetchExchangeRates();
              final exchangeRate = exchangeRates.firstWhere(
                (rate) =>
                    rate.currencyCode.toLowerCase() == currency.toLowerCase(),
                orElse: () =>
                    throw Exception('Exchange rate for $currency not found'),
              );
              originalPriceInUAH = price * exchangeRate.rateToUah;
            } else {
              originalPriceInUAH = price;
            }
          } else {
            originalPriceInUAH = null;
          }
        } else {
          // For non-negotiable listings, price and currency are required
          if (price == null || currency == null) {
            throw Exception('Non-free listings must have price and currency');
          }
          if (price < 0) {
            throw Exception('Price cannot be negative');
          }
          // Convert price to UAH if currency is not UAH
          if (currency.toLowerCase() != 'uah') {
            final exchangeRates = await _exchangeRateService
                .fetchExchangeRates();
            final exchangeRate = exchangeRates.firstWhere(
              (rate) =>
                  rate.currencyCode.toLowerCase() == currency.toLowerCase(),
              orElse: () =>
                  throw Exception('Exchange rate for $currency not found'),
            );
            originalPriceInUAH = price * exchangeRate.rateToUah;
          } else {
            originalPriceInUAH = price;
          }
          originalCurrency = currency; // Assign here
        }
      }

      // Get current user
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to create a listing');
      }

      // Upload images first
      final List<String> imageUrls = [];
      if (images.isNotEmpty) {
        for (var image in images) {
          final imageUrl = await _storageService.uploadImage(image);
          imageUrls.add(imageUrl);
        }
      }

      // Create the listing
      final response = await _client
          .from('listings')
          .insert({
            'title': title,
            'description': description,
            'category_id': categoryId,
            'subcategory_id': subcategoryId,
            'location': location ?? '',
            'is_free': isFree,
            'currency': currency,
            'price': price,
            'original_currency': originalCurrency, // Store original currency
            'original_price': originalPriceInUAH, // Store original price in UAH
            'price_in_uah':
                originalPriceInUAH, // Store price in UAH as well for filtering
            'is_negotiable': isNegotiable ?? false,
            'phone_number': phoneNumber,
            'whatsapp': whatsapp,
            'telegram': telegram,
            'viber': viber,
            'user_id': user.id,
            'custom_attributes': customAttributes,
            'photos':
                imageUrls, // Store image URLs directly in the listings table
            'address': address,
            'region': region,
            'latitude': latitude,
            'longitude': longitude,
            'real_estate_type': realEstateType,
            'mileage_thousands_km': mileageThousands,
            'job_type': jobType,
            'help_type': helpType,
            'giveaway_type': giveawayType,
            'condition_type': conditionType,
            'size': size,
            'radius_r': radiusR,
            'gender_type': genderType,
            'make_id': makeId,
            'model_id': modelId,
            'style_id': styleId,
            'model_year_id': modelYearId,
          })
          .select('id')
          .single();

      final listingId = response['id'] as String;

      return listingId;
    } catch (error) {
      throw Exception('Failed to create listing: $error');
    }
  }

  Future<Listing> getListingById(String listingId) async {
    try {
      final response = await _client
          .from('listings')
          .select(
            '*, categories!id(name), subcategories!id(name)',
          ) // Fetch category and subcategory names
          .eq('id', listingId)
          .single();

      print(
        'ListingService.getListingById: Supabase response: $response',
      ); // NEW: Logging full response
      final categoryName =
          (response['categories'] as Map<String, dynamic>)['name'] as String?;
      final subcategoryName =
          (response['subcategories'] as Map<String, dynamic>)['name']
              as String?;
      final latitudeFromResponse =
          response['latitude'] as double?; // NEW: Extract latitude
      final longitudeFromResponse =
          response['longitude'] as double?; // NEW: Extract longitude
      print(
        'ListingService.getListingById: Latitude from response: $latitudeFromResponse',
      ); // NEW: Logging latitude value
      print(
        'ListingService.getListingById: Longitude from response: $longitudeFromResponse',
      ); // NEW: Logging longitude value

      return Listing.fromJson({
        ...response,
        'category_name': categoryName,
        'subcategory_name': subcategoryName,
      });
    } catch (error) {
      throw Exception('Failed to fetch listing: $error');
    }
  }

  Future<Map<String, double>> getMinMaxPrices(String currency) async {
    try {
      // Get min price
      final minResponse = await _client
          .from('listings')
          .select('price')
          .eq('currency', currency)
          .not('price', 'is', null) // Exclude null prices
          .order('price', ascending: true)
          .limit(1)
          .single();

      final double minPrice = (minResponse['price'] as num?)?.toDouble() ?? 0.0;

      // Get max price
      final maxResponse = await _client
          .from('listings')
          .select('price')
          .eq('currency', currency)
          .not('price', 'is', null) // Exclude null prices
          .order('price', ascending: false)
          .limit(1)
          .single();

      final double maxPrice =
          (maxResponse['price'] as num?)?.toDouble() ??
          100.0; // Default max if no listings

      return {'minPrice': minPrice, 'maxPrice': maxPrice};
    } catch (error) {
      // Return default values in case of an error or no listings
      return {'minPrice': 0.0, 'maxPrice': 100.0};
    }
  }

  // Оновлений метод для оновлення статусу оголошення
  Future<void> updateListingStatus(String listingId, String status) async {
    try {
      // Оновлюємо статус
      await _client
          .from('listings')
          .update({'status': status})
          .eq('id', listingId);
    } catch (e) {
      throw Exception('Не вдалося оновити статус оголошення: $e');
    }
  }

  // Додаємо метод для видалення оголошення
  Future<void> deleteListing(String listingId) async {
    try {
      // Перевіряємо поточного користувача
      final user = _client.auth.currentUser;

      if (user == null) {
        throw Exception('Користувач не авторизований');
      }

      await _client.from('listings').delete().eq('id', listingId);
    } catch (e) {
      throw Exception('Не вдалося видалити оголошення: $e');
    }
  }

  // Додаємо метод для оновлення оголошення
  Future<void> updateListing({
    required String listingId,
    required String title,
    required String description,
    required String categoryId,
    required String subcategoryId,
    String? location,
    required bool isFree,
    String? currency,
    double? price,
    bool? isNegotiable,
    String? phoneNumber,
    String? whatsapp,
    String? telegram,
    String? viber,
    String? address,
    String? region,
    double? latitude,
    double? longitude,
    required Map<String, dynamic> customAttributes,
    List<XFile>? newImages,
    List<String>? existingImageUrls,
    String? realEstateType,
    double? mileageThousands,
    String? jobType,
    String? helpType,
    String? giveawayType,
    String? conditionType,
    String? size,
    double? radiusR,
    String? genderType,
    String? makeId,
    String? modelId,
    String? styleId,
    String? modelYearId,
  }) async {
    try {
      // Validate price and currency based on isFree and isNegotiable
      late double? originalPriceInUAH; // Declare here
      late String? originalCurrency; // Declare here
      if (isFree) {
        if (price != null || currency != null) {
          throw Exception('Free listings cannot have price or currency');
        }
        originalPriceInUAH =
            null; // For free listings, original price in UAH is null
        originalCurrency = null; // For free listings, no currency
      } else {
        if (isNegotiable == true) {
          // For negotiable listings, price can be null or any valid price
          if (price != null && price < 0) {
            throw Exception('Price cannot be negative');
          }
          // Set originalCurrency for negotiable listings
          originalCurrency = currency;
          if (price != null && currency != null) {
            // Convert price to UAH if currency is not UAH
            if (currency.toLowerCase() != 'uah') {
              final exchangeRates = await _exchangeRateService
                  .fetchExchangeRates();
              final exchangeRate = exchangeRates.firstWhere(
                (rate) =>
                    rate.currencyCode.toLowerCase() == currency.toLowerCase(),
                orElse: () =>
                    throw Exception('Exchange rate for $currency not found'),
              );
              originalPriceInUAH = price * exchangeRate.rateToUah;
            } else {
              originalPriceInUAH = price;
            }
          } else {
            originalPriceInUAH = null;
          }
        } else {
          // For non-negotiable listings, price and currency are required
          if (price == null || currency == null) {
            throw Exception('Non-free listings must have price and currency');
          }
          if (price < 0) {
            throw Exception('Price cannot be negative');
          }
          // Convert price to UAH if currency is not UAH
          if (currency.toLowerCase() != 'uah') {
            final exchangeRates = await _exchangeRateService
                .fetchExchangeRates();
            final exchangeRate = exchangeRates.firstWhere(
              (rate) =>
                  rate.currencyCode.toLowerCase() == currency.toLowerCase(),
              orElse: () =>
                  throw Exception('Exchange rate for $currency not found'),
            );
            originalPriceInUAH = price * exchangeRate.rateToUah;
          } else {
            originalPriceInUAH = price;
          }
          originalCurrency = currency; // Assign here
        }
      }

      // Get current user
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to update a listing');
      }

      // Upload new images if any
      final List<String> imageUrls = [];
      if (existingImageUrls != null) {
        imageUrls.addAll(existingImageUrls);
      }

      if (newImages != null && newImages.isNotEmpty) {
        for (var image in newImages) {
          final imageUrl = await _storageService.uploadImage(image);
          imageUrls.add(imageUrl);
        }
      }

      final updatePayload = {
        'title': title,
        'description': description,
        'category_id': categoryId,
        'subcategory_id': subcategoryId,
        'location': location ?? '',
        'is_free': isFree,
        'currency': currency,
        'price': price,
        'original_currency': originalCurrency, // Store original currency
        'original_price': originalPriceInUAH, // Store original price in UAH
        'price_in_uah':
            originalPriceInUAH, // Store price in UAH as well for filtering
        'is_negotiable': isNegotiable ?? false,
        'phone_number': phoneNumber,
        'whatsapp': whatsapp,
        'telegram': telegram,
        'viber': viber,
        'custom_attributes': customAttributes,
        'photos': imageUrls,
        'address': address,
        'region': region,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
        'real_estate_type': realEstateType,
        'job_type': jobType,
        'help_type': helpType,
        'giveaway_type': giveawayType,
        'condition_type': conditionType,
        'size': size,
        'radius_r': radiusR,
        'gender_type': genderType,
        'make_id': makeId,
        'model_id': modelId,
        'style_id': styleId,
        'model_year_id': modelYearId,
      };

      if (mileageThousands != null) {
        updatePayload['mileage_thousands_km'] = mileageThousands;
      }

      await _client.from('listings').update(updatePayload).eq('id', listingId);
    } catch (error) {
      throw Exception('Failed to update listing: $error');
    }
  }
}
