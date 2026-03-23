import 'package:zeno/utils/price_formatter.dart';

class Listing {
  final String id;
  final String title;
  final String description;
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
  final Map<String, dynamic> customAttributes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> photos;
  final bool isNegotiable;
  bool isFavorite;
  final String? address;
  final String? region;
  final double? latitude;
  final double? longitude;
  final String? city; // NEW: Add city field
  final String? categoryName;
  final String? subcategoryName;
  final String? realEstateType;
  final double? mileageThousandsKm;
  final String? jobType;
  final String? helpType;
  final String? giveawayType;
  final String? conditionType;
  final String? size;
  final double? radiusR;
  final String? genderType;
  final String? makeId;
  final String? modelId;
  final String? styleId;
  final String? modelYearId;

  Listing({
    required this.id,
    required this.title,
    required this.description,
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
    required this.customAttributes,
    required this.createdAt,
    required this.updatedAt,
    required this.photos,
    this.isNegotiable = false,
    this.isFavorite = false,
    this.address,
    this.region,
    this.latitude,
    this.longitude,
    this.city, // NEW: Add city to constructor
    this.categoryName,
    this.subcategoryName,
    this.realEstateType,
    this.mileageThousandsKm,
    this.jobType,
    this.helpType,
    this.giveawayType,
    this.conditionType,
    this.size,
    this.radiusR,
    this.genderType,
    this.makeId,
    this.modelId,
    this.styleId,
    this.modelYearId,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    final city = _extractCityFromAddress(json['address'] as String?);
    print('Listing: fromJson - Extracted city: $city');
    return Listing(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
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
      customAttributes: json['custom_attributes'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isNegotiable: json['is_negotiable'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      address: json['address'] as String?,
      region: json['region'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      city: city,
      categoryName: json['category_name'] as String?,
      subcategoryName: json['subcategory_name'] as String?,
      realEstateType: json['real_estate_type'] as String?,
      mileageThousandsKm: json['mileage_thousands_km'] != null
          ? (json['mileage_thousands_km'] as num).toDouble()
          : null,
      jobType: json['job_type'] as String?,
      helpType: json['help_type'] as String?,
      giveawayType: json['giveaway_type'] as String?,
      conditionType: json['condition_type'] as String?,
      size: json['size'] as String?,
      radiusR: json['radius_r'] as double?,
      genderType: json['gender_type'] as String?,
      makeId: json['make_id'] as String?,
      modelId: json['model_id'] as String?,
      styleId: json['style_id'] as String?,
      modelYearId: json['model_year_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'user_id': userId,
      'custom_attributes': customAttributes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'photos': photos,
      'is_negotiable': isNegotiable,
      'is_favorite': isFavorite,
      'address': address,
      'region': region,
      'latitude': latitude,
      'longitude': longitude,
      'city': city, // NEW: Include city in JSON serialization
      'category_name': categoryName,
      'subcategory_name': subcategoryName,
      'real_estate_type': realEstateType,
      'mileage_thousands_km': mileageThousandsKm,
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
  }

  String get formattedPrice {
    if (isFree) return 'Віддам безкоштовно';
    if (price == null) {
      if (isNegotiable) {
        return 'Договірна';
      }
      return 'Ціна не вказана';
    }

    return PriceFormatter.formatCurrency(price!, currency: currency);
  }
}

// NEW: Top-level function to extract city from address
String? _extractCityFromAddress(String? address) {
  print(
    'Listing: _extractCityFromAddress - incoming address: $address',
  ); // NEW: Logging
  if (address == null || address.isEmpty) {
    print(
      'Listing: _extractCityFromAddress - address is null or empty',
    ); // NEW: Logging
    return null;
  }
  // Simple heuristic: assume city is the first part before a comma, or the whole string if no comma
  final parts = address.split(',');
  if (parts.isNotEmpty) {
    final city = parts[0].trim();
    print(
      'Listing: _extractCityFromAddress - extracted city: $city',
    ); // NEW: Logging
    return city;
  }
  print('Listing: _extractCityFromAddress - no parts found'); // NEW: Logging
  return null;
}
