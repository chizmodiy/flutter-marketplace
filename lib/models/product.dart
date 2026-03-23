import 'package:zeno/utils/price_formatter.dart';

import '../models/listing.dart';

class Product {
  final String id;
  final String title;
  final String? description;
  final String categoryId;
  final String subcategoryId;
  final String location;
  final bool isFree;
  final String? currency;
  final double? price;
  final String? phoneNumber;
  final String? whatsapp;
  final String? telegram;
  final String? viber;
  final String userId;
  final Map<String, dynamic>? customAttributes;
  final String? status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> photos;
  final bool isNegotiable;
  final String? address;
  final String? region;
  final double? latitude;
  final double? longitude;
  final String? city; // NEW: Add city field
  final String? categoryName;
  final String? subcategoryName;
  final double? displayPrice; // New field for converted price
  final String? displayCurrency; // New field for display currency
  final double? priceInUah; // NEW: Price in UAH
  final double? priceInUsd; // NEW: Price in USD
  final double? priceInEur; // NEW: Price in EUR
  final double? mileageThousandsKm;
  final String? jobType;
  final String? helpType;
  final String? giveawayType;
  final String? conditionType;
  final String? size;
  final double? radiusR;
  final String? genderType;
  final String? realEstateType;
  final String? makeId;
  final String? modelId;
  final String? styleId;
  final String? modelYearId;

  Product({
    required this.id,
    required this.title,
    this.description,
    required this.categoryId,
    required this.subcategoryId,
    required this.location,
    required this.isFree,
    this.currency,
    this.price,
    this.phoneNumber,
    this.whatsapp,
    this.telegram,
    this.viber,
    required this.userId,
    this.customAttributes,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.photos,
    this.isNegotiable = false,
    this.address,
    this.region,
    this.latitude,
    this.longitude,
    this.city, // NEW: Add city to constructor
    this.categoryName,
    this.subcategoryName,
    this.displayPrice, // Initialize new field
    this.displayCurrency, // Initialize new field
    this.priceInUah, // NEW: Initialize new field
    this.priceInUsd, // NEW: Initialize new field
    this.priceInEur, // NEW: Initialize new field
    this.mileageThousandsKm,
    this.jobType,
    this.helpType,
    this.giveawayType,
    this.conditionType,
    this.size,
    this.radiusR,
    this.genderType,
    this.realEstateType,
    this.makeId,
    this.modelId,
    this.styleId,
    this.modelYearId,
  });

  Product copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    String? subcategoryId,
    String? location,
    bool? isFree,
    String? currency,
    double? price,
    String? phoneNumber,
    String? whatsapp,
    String? telegram,
    String? viber,
    String? userId,
    Map<String, dynamic>? customAttributes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? photos,
    bool? isNegotiable,
    String? address,
    String? region,
    double? latitude,
    double? longitude,
    String? city, // NEW: Add city to copyWith
    String? categoryName,
    String? subcategoryName,
    double? displayPrice,
    String? displayCurrency,
    double? priceInUah, // NEW: Add to copyWith
    double? priceInUsd, // NEW: Add to copyWith
    double? priceInEur, // NEW: Add to copyWith
    double? mileageThousandsKm,
    String? jobType,
    String? helpType,
    String? giveawayType,
    String? conditionType,
    String? size,
    double? radiusR,
    String? genderType,
    String? realEstateType,
    String? makeId,
    String? modelId,
    String? styleId,
    String? modelYearId,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      location: location ?? this.location,
      isFree: isFree ?? this.isFree,
      currency: currency ?? this.currency,
      price: price ?? this.price,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      whatsapp: whatsapp ?? this.whatsapp,
      telegram: telegram ?? this.telegram,
      viber: viber ?? this.viber,
      userId: userId ?? this.userId,
      customAttributes: customAttributes ?? this.customAttributes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photos: photos ?? this.photos,
      isNegotiable: isNegotiable ?? this.isNegotiable,
      address: address ?? this.address,
      region: region ?? this.region,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city, // NEW: Assign city in copyWith
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      displayPrice: displayPrice ?? this.displayPrice,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      priceInUah: priceInUah ?? this.priceInUah, // NEW: Assign in copyWith
      priceInUsd: priceInUsd ?? this.priceInUsd, // NEW: Assign in copyWith
      priceInEur: priceInEur ?? this.priceInEur, // NEW: Assign in copyWith
      mileageThousandsKm: mileageThousandsKm ?? this.mileageThousandsKm,
      jobType: jobType ?? this.jobType,
      helpType: helpType ?? this.helpType,
      giveawayType: giveawayType ?? this.giveawayType,
      conditionType: conditionType ?? this.conditionType,
      size: size ?? this.size,
      radiusR: radiusR ?? this.radiusR,
      genderType: genderType ?? this.genderType,
      realEstateType: realEstateType ?? this.realEstateType,
      makeId: makeId ?? this.makeId,
      modelId: modelId ?? this.modelId,
      styleId: styleId ?? this.styleId,
      modelYearId: modelYearId ?? this.modelYearId,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      print('Product.fromJson: Parsing product with ID: ${json['id']}');
      final isNegotiable = json['is_negotiable'] as bool? ?? false;

      return Product(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        categoryId: json['category_id'] as String,
        subcategoryId: json['subcategory_id'] as String,
        location: json['location'] as String,
        isFree: json['is_free'] as bool,
        currency: json['currency'] as String?,
        price: json['price'] != null ? (json['price'] as num).toDouble() : null,
        phoneNumber: json['phone_number'] as String?,
        whatsapp: json['whatsapp'] as String?,
        telegram: json['telegram'] as String?,
        viber: json['viber'] as String?,
        userId: json['user_id'] as String,
        customAttributes: json['custom_attributes'] != null
            ? Map<String, dynamic>.from(json['custom_attributes'] as Map)
            : null,
        status: json['status'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
        isNegotiable: isNegotiable,
        address: json['address'] as String?,
        region: json['region'] as String?,
        latitude: json['latitude'] != null
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] != null
            ? (json['longitude'] as num).toDouble()
            : null,
        city: json['city'] as String?, // NEW: Parse city from JSON
        categoryName: json['categories'] != null
            ? (json['categories'] as Map<String, dynamic>)['name'] as String?
            : null, // Corrected to use 'categories' relation
        subcategoryName: json['subcategories'] != null
            ? (json['subcategories'] as Map<String, dynamic>)['name'] as String?
            : null, // Corrected to use 'subcategories' relation
        displayPrice: json['display_price'] != null
            ? (json['display_price'] as num).toDouble()
            : null, // Parse new field
        displayCurrency: json['display_currency'] as String?, // Parse new field
        priceInUah: json['price_in_uah'] != null
            ? (json['price_in_uah'] as num).toDouble()
            : null, // NEW: Parse price in UAH
        priceInUsd: json['price_in_usd'] != null
            ? (json['price_in_usd'] as num).toDouble()
            : null, // NEW: Parse price in USD
        priceInEur: json['price_in_eur'] != null
            ? (json['price_in_eur'] as num).toDouble()
            : null, // NEW: Parse price in EUR
        mileageThousandsKm: json['mileage_thousands_km'] != null
            ? (json['mileage_thousands_km'] as num).toDouble()
            : null,
        jobType: json['job_type'] as String?,
        helpType: json['help_type'] as String?,
        giveawayType: json['giveaway_type'] as String?,
        conditionType: json['condition_type'] as String?,
        size: json['size'] as String?,
        radiusR: json['radius_r'] != null
            ? (json['radius_r'] as num).toDouble()
            : null,
        genderType: json['gender_type'] as String?,
        realEstateType: json['real_estate_type'] as String?,
        makeId: json['make_id'] as String?,
        modelId: json['model_id'] as String?,
        styleId: json['style_id'] as String?,
        modelYearId: json['model_year_id'] as String?,
      );
    } catch (e, stackTrace) {
      print(
        'Product.fromJson: Error parsing product with ID: ${json['id']}, Error: $e',
      );
      print('Product.fromJson: Stack trace: $stackTrace');
      print('Product.fromJson: JSON data: $json');
      rethrow;
    }
  }

  String get formattedDate {
    return '${createdAt.day} ${_getMonthName(createdAt.month)} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
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

  String get formattedPrice {
    if (isFree) return 'Віддам безкоштовно';
    if (displayPrice == null) {
      if (isNegotiable) {
        return 'Договірна';
      }
      return 'Ціна не вказана';
    }

    return PriceFormatter.formatCurrency(
      displayPrice!,
      currency: displayCurrency,
    );
  }

  // Додаємо getter для сумісності зі старим кодом
  List<String> get images => photos;

  double get priceValue {
    if (isFree) return 0.0;
    return price ?? 0.0;
  }

  Listing toListing() {
    return Listing(
      id: id,
      title: title,
      description: description ?? '',
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      location: location,
      isFree: isFree,
      currency: currency,
      price: price,
      phoneNumber: phoneNumber,
      whatsapp: whatsapp,
      telegram: telegram,
      viber: viber,
      userId: userId,
      customAttributes: customAttributes ?? {},
      createdAt: createdAt,
      updatedAt: updatedAt,
      photos: photos,
      isNegotiable: isNegotiable,
      isFavorite: false,
      address: address,
      region: region,
      latitude: latitude,
      longitude: longitude,
      city: city, // NEW: Populate city field
      categoryName: categoryName,
      subcategoryName: subcategoryName,
      realEstateType: realEstateType,
      mileageThousandsKm: mileageThousandsKm,
      jobType: jobType,
      helpType: helpType,
      giveawayType: giveawayType,
      conditionType: conditionType,
      size: size,
      radiusR: radiusR,
      genderType: genderType,
      makeId: makeId,
      modelId: modelId,
      styleId: styleId,
      modelYearId: modelYearId,
    );
  }
}
