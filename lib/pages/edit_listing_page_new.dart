import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/category.dart';
import '../services/category_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subcategory.dart';
import '../services/subcategory_service.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import '../models/region.dart';
import '../services/region_service.dart';
import '../models/city.dart';
import '../utils/price_formatter.dart';
import '../services/listing_service.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import '../widgets/location_creation_block.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../widgets/keyboard_dismisser.dart';
import '../models/listing.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import '../services/car_service.dart';

class EditListingPageNew extends StatefulWidget {
  final Listing listing;

  const EditListingPageNew({super.key, required this.listing});

  @override
  State<EditListingPageNew> createState() => _EditListingPageNewState();
}

class _EditListingPageNewState extends State<EditListingPageNew> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<dynamic> _selectedImages =
      []; // Може містити String (URL) або XFile
  final PageController _imagePageController = PageController();

  final GlobalKey _categoryButtonKey = GlobalKey();
  final GlobalKey _subcategoryButtonKey = GlobalKey();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Category? _selectedCategory;
  List<Category> _categories = [];
  bool _isLoadingCategories = true;
  Subcategory? _selectedSubcategory;
  List<Subcategory> _subcategories = [];
  bool _isLoadingSubcategories = false;
  Region? _selectedRegion;
  List<Region> _regions = [];
  bool _isLoadingRegions = true;
  bool _isForSale = true;
  String _selectedCurrency = 'UAH';
  bool _isNegotiablePrice = false;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _telegramController = TextEditingController();
  final TextEditingController _viberController = TextEditingController();
  final TextEditingController _radiusRController = TextEditingController();
  String _selectedMessenger = 'phone';
  final Map<String, TextEditingController> _extraFieldControllers = {};
  final Map<String, dynamic> _extraFieldValues = {};
  bool _isLoading = false;

  final TextEditingController _citySearchController = TextEditingController();

  City? _selectedCity;
  Timer? _debounceTimer;
  String? _selectedAddress;
  String? _selectedRegionName;
  double? _selectedLatitude;
  double? _selectedLongitude;
  final ProfileService _profileService = ProfileService();
  bool _isFormValid = false; // NEW: Add form validity state
  String _realEstateType = 'sale';
  String _jobType = 'offering';
  String _helpType = 'offering';
  String _giveawayType = 'giving';
  String _conditionType = 'new';
  String? _selectedSize; // Add this line
  String _genderType =
      'both'; // Default to "Обидва" for Children's World category

  // Нові поля для легкових авто та авто з Польщі
  Make? _selectedMake;
  Model? _selectedModel;
  Style? _selectedStyle;
  ModelYear? _selectedModelYear;
  List<Make> _makes = [];
  List<Model> _models = [];
  List<Style> _styles = [];
  List<ModelYear> _modelYears = [];
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  bool _isLoadingStyles = false;
  bool _isLoadingModelYears = false;
  final GlobalKey _makeKey = GlobalKey();
  final GlobalKey _modelKey = GlobalKey();
  final GlobalKey _styleKey = GlobalKey();
  final GlobalKey _modelYearKey = GlobalKey();
  final GlobalKey _makeSelectorKey = GlobalKey();
  final GlobalKey _modelSelectorKey = GlobalKey();
  final GlobalKey _styleSelectorKey = GlobalKey();
  final GlobalKey _modelYearSelectorKey = GlobalKey();
  bool _isMakeOpen = false;
  bool _isModelOpen = false;
  bool _isStyleOpen = false;
  bool _isModelYearOpen = false;
  final TextEditingController _makeSearchController = TextEditingController();
  final TextEditingController _modelSearchController = TextEditingController();
  final TextEditingController _styleSearchController = TextEditingController();
  final CarService _carService = CarService();

  @override
  void initState() {
    super.initState();
    print('EditListingPageNew: initState called'); // NEW: Log initState call
    _initializeData();
    _loadCategories();
    _loadRegions();
    _addFormListeners();
    _validateForm(); // NEW: Initial form validation
    _realEstateType = widget.listing.realEstateType ?? 'sale';
    _jobType = widget.listing.jobType ?? 'offering';
    _helpType = widget.listing.helpType ?? 'offering';
    _giveawayType = widget.listing.giveawayType ?? 'giving';
    _conditionType = widget.listing.conditionType ?? 'new';
    _selectedSize = widget.listing.size; // Initialize _selectedSize

    _whatsappController.text = widget.listing.whatsapp ?? '';
    if (widget.listing.whatsapp != null && widget.listing.whatsapp!.isNotEmpty)
      _selectedMessenger = 'whatsapp';
    _telegramController.text = widget.listing.telegram ?? '';
    if (widget.listing.telegram != null && widget.listing.telegram!.isNotEmpty)
      _selectedMessenger = 'telegram';
    _viberController.text = widget.listing.viber ?? '';
    if (widget.listing.viber != null && widget.listing.viber!.isNotEmpty)
      _selectedMessenger = 'viber';

    _radiusRController.text = widget.listing.radiusR?.toString() ?? '';
    _genderType = widget.listing.genderType ?? 'both';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final userStatus = await _profileService.getUserStatus();
        if (userStatus == 'blocked') {
          _showBlockedUserBottomSheet();
        }
      }
    });
  }

  Future<void> _initializeData() async {
    // Changed to async
    // Ініціалізуємо дані з існуючого оголошення
    _titleController.text = widget.listing.title;
    _descriptionController.text = widget.listing.description;

    if (widget.listing.isFree) {
      _isForSale = false;
      _priceController.clear();
      _selectedCurrency = 'UAH';
      _isNegotiablePrice = false;
    } else if (widget.listing.price != null && widget.listing.price! > 0) {
      final priceString = widget.listing.price! % 1 == 0
          ? widget.listing.price!.toInt().toString()
          : widget.listing.price!.toString();
      _priceController.text = PriceInputFormatter()
          .formatEditUpdate(
              TextEditingValue.empty, TextEditingValue(text: priceString))
          .text;
      _isForSale = true;
    } else {
      _isForSale = false; // Fallback if price is null and not explicitly free
    }

    if (widget.listing.currency != null) {
      _selectedCurrency = widget.listing.currency!;
    }

    // Ініціалізуємо контактні дані
    if (widget.listing.phoneNumber != null) {
      String phoneNumber = widget.listing.phoneNumber!;
      if (phoneNumber.startsWith('+380')) {
        _phoneController.text = phoneNumber.substring(4); // Видаляємо +380
      } else {
        _phoneController.text = phoneNumber;
      }
      _selectedMessenger = 'phone';
    } else if (widget.listing.whatsapp != null) {
      String whatsapp = widget.listing.whatsapp!;
      if (whatsapp.startsWith('+380')) {
        _whatsappController.text = whatsapp.substring(4); // Видаляємо +380
      } else {
        _whatsappController.text = whatsapp;
      }
      _selectedMessenger = 'whatsapp';
    } else if (widget.listing.telegram != null) {
      _telegramController.text = widget.listing.telegram!;
      _selectedMessenger = 'telegram';
    } else if (widget.listing.viber != null) {
      String viber = widget.listing.viber!;
      if (viber.startsWith('+380')) {
        _viberController.text = viber.substring(4); // Видаляємо +380
      } else {
        _viberController.text = viber;
      }
      _selectedMessenger = 'viber';
    }

    // Initialize location data
    _selectedAddress = widget.listing.address;
    _selectedRegionName = widget.listing.region;
    _selectedLatitude = widget.listing.latitude;
    _selectedLongitude = widget.listing.longitude;
    // NEW: Initialize _selectedCity from listing or address
    final cityFromAddress = _extractCityFromAddress(widget.listing.address);
    _selectedCity = widget.listing.city != null
        ? City(
            name: widget.listing.city!,
            regionId: widget.listing.region ?? '',
          )
        : (cityFromAddress != null
              ? City(
                  name: cityFromAddress,
                  regionId: widget.listing.region ?? '',
                )
              : null);

    // Ініціалізуємо зображення
    if (widget.listing.photos != null && widget.listing.photos!.isNotEmpty) {
      _selectedImages.addAll(
        widget.listing.photos!,
      ); // Додаємо існуючі URL зображень
    }

    // NEW: Initialize category and subcategory
    await _loadCategories(); // Ensure categories are loaded first
    _selectedCategory = _categories.firstWhereOrNull(
      (cat) => cat.id == widget.listing.categoryId,
    );
    if (_selectedCategory != null) {
      await _loadSubcategories(); // Ensure subcategories are loaded based on selected category
      _selectedSubcategory = _subcategories.firstWhereOrNull(
        (sub) => sub.id == widget.listing.subcategoryId,
      );
    }

    // NEW: Initialize extra fields
    if (widget.listing.customAttributes.isNotEmpty) {
      _extraFieldValues.addAll(widget.listing.customAttributes);
      // Initialize extra field controllers with values
      _selectedSubcategory?.extraFields.forEach((field) {
        final value = widget.listing.customAttributes[field.name];
        if (value != null) {
          if (field.type == 'number') {
            _extraFieldControllers[field.name]?.text = value.toString();
          } else if (field.type == 'range') {
            // Assuming range values are stored as a map or similar in customAttributes
            if (value is Map<String, dynamic>) {
              _extraFieldControllers['${field.name}_min']?.text =
                  (value['min'] ?? '').toString();
              _extraFieldControllers['${field.name}_max']?.text =
                  (value['max'] ?? '').toString();
            }
          }
          // For select fields, _extraFieldValues is enough
        }
      });
    }

    // Initialize car filters if this is a car listing
    if (_selectedCategory?.name == 'Авто' &&
        (_selectedSubcategory?.name == 'Легкові автомобілі' ||
            _selectedSubcategory?.name == 'Автомобілі з Польщі')) {
      print(
        'EditListingPageNew: Initializing car filters. makeId: ${widget.listing.makeId}, modelId: ${widget.listing.modelId}, styleId: ${widget.listing.styleId}, modelYearId: ${widget.listing.modelYearId}',
      );
      await _loadMakes();
      // Перевіряємо, що марки завантажені та є makeId
      if (_makes.isNotEmpty && widget.listing.makeId != null) {
        await _initializeCarFiltersFromListing();
      } else {
        print(
          'EditListingPageNew: Cannot initialize car filters - makes empty: ${_makes.isEmpty}, makeId null: ${widget.listing.makeId == null}',
        );
        // Якщо makeId null, це нормально - просто не було обрано марку при створенні
        // Дропдауни будуть порожніми, користувач зможе їх заповнити
      }
    }
  }

  // Load makes when category "Авто" and subcategory "Легкові автомобілі" is selected
  Future<void> _loadMakes() async {
    if (_selectedCategory?.name != 'Авто' ||
        (_selectedSubcategory?.name != 'Легкові автомобілі' &&
            _selectedSubcategory?.name != 'Автомобілі з Польщі')) {
      print(
        'EditListingPageNew: _loadMakes skipped - category: ${_selectedCategory?.name}, subcategory: ${_selectedSubcategory?.name}',
      );
      return;
    }

    print('EditListingPageNew: Loading makes...');
    setState(() {
      _isLoadingMakes = true;
    });

    try {
      final makes = await _carService.getMakes();
      print('EditListingPageNew: Loaded ${makes.length} makes');
      setState(() {
        _makes = makes;
        _isLoadingMakes = false;
      });
    } catch (error) {
      print('EditListingPageNew: Error loading makes: $error');
      setState(() {
        _isLoadingMakes = false;
      });
    }
  }

  // Load models when make is selected
  Future<void> _loadModels(String makeId, {bool resetSelection = true}) async {
    setState(() {
      _isLoadingModels = true;
      if (resetSelection) {
        _selectedModel = null;
        _selectedStyle = null;
        _selectedModelYear = null;
        _models.clear();
        _styles.clear();
        _modelYears.clear();
      }
    });

    try {
      final models = await _carService.getModels(makeId);
      setState(() {
        _models = models;
        _isLoadingModels = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  // Load styles when model is selected
  Future<void> _loadStyles(String modelId, {bool resetSelection = true}) async {
    setState(() {
      _isLoadingStyles = true;
      if (resetSelection) {
        _selectedStyle = null;
        _selectedModelYear = null;
        _styles.clear();
        _modelYears.clear();
      }
    });

    try {
      final styles = await _carService.getStyles(modelId);
      setState(() {
        _styles = styles;
        _isLoadingStyles = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingStyles = false;
      });
    }
  }

  // Load model years when style is selected
  Future<void> _loadModelYears(
    String styleId, {
    bool resetSelection = true,
  }) async {
    setState(() {
      _isLoadingModelYears = true;
      if (resetSelection) {
        _selectedModelYear = null;
        _modelYears.clear();
      }
    });

    try {
      final modelYears = await _carService.getModelYears(styleId);
      print(
        'EditListingPageNew: _loadModelYears loaded ${modelYears.length} model years for styleId: $styleId',
      );
      setState(() {
        _modelYears = modelYears;
        _isLoadingModelYears = false;
      });
      print(
        'EditListingPageNew: _loadModelYears after setState, _modelYears.length: ${_modelYears.length}',
      );
    } catch (error) {
      print('EditListingPageNew: Error loading model years: $error');
      setState(() {
        _isLoadingModelYears = false;
      });
    }
  }

  // Initialize car filters from existing listing data
  Future<void> _initializeCarFiltersFromListing() async {
    if (widget.listing.makeId == null) {
      print('EditListingPageNew: makeId is null');
      return;
    }

    if (_makes.isEmpty) {
      print('EditListingPageNew: _makes is empty, waiting...');
      // Чекаємо трохи, можливо дані ще завантажуються
      await Future.delayed(Duration(milliseconds: 100));
      if (_makes.isEmpty) {
        print('EditListingPageNew: _makes still empty after wait');
        return;
      }
    }

    print(
      'EditListingPageNew: Looking for make with id: ${widget.listing.makeId}',
    );
    print('EditListingPageNew: Available makes count: ${_makes.length}');

    // Find and set Make
    final make = _makes.firstWhereOrNull((m) => m.id == widget.listing.makeId);
    if (make == null) {
      print(
        'EditListingPageNew: Make not found for id: ${widget.listing.makeId}',
      );
      print(
        'EditListingPageNew: Available make IDs: ${_makes.map((m) => m.id).toList()}',
      );
      return;
    }

    print('EditListingPageNew: Found make: ${make.name}');
    setState(() {
      _selectedMake = make;
    });

    // Load and set Model
    await _loadModels(_selectedMake!.id, resetSelection: false);
    if (widget.listing.modelId != null && _models.isNotEmpty) {
      final model = _models.firstWhereOrNull(
        (m) => m.id == widget.listing.modelId,
      );
      if (model != null) {
        setState(() {
          _selectedModel = model;
        });

        // Load and set Style
        await _loadStyles(_selectedModel!.id, resetSelection: false);
        if (widget.listing.styleId != null && _styles.isNotEmpty) {
          final style = _styles.firstWhereOrNull(
            (s) => s.id == widget.listing.styleId,
          );
          if (style != null) {
            setState(() {
              _selectedStyle = style;
            });

            // Load and set ModelYear
            // Спочатку завантажуємо роки для поточного стилю
            await _loadModelYears(_selectedStyle!.id, resetSelection: false);
            print(
              'EditListingPageNew: Loaded ${_modelYears.length} model years for style ${_selectedStyle!.id}',
            );
            print(
              'EditListingPageNew: Looking for modelYearId: ${widget.listing.modelYearId}',
            );

            if (widget.listing.modelYearId != null) {
              // Спочатку шукаємо в завантажених роках для поточного стилю
              var modelYear = _modelYears.firstWhereOrNull(
                (my) => my.id == widget.listing.modelYearId,
              );

              // Якщо не знайдено, спробуємо завантажити рік за ID безпосередньо
              if (modelYear == null) {
                print(
                  'EditListingPageNew: ModelYear not found in loaded years, trying to load by ID directly',
                );
                final loadedModelYear = await _carService.getModelYearById(
                  widget.listing.modelYearId!,
                );
                if (loadedModelYear != null) {
                  print(
                    'EditListingPageNew: Found modelYear by ID: ${loadedModelYear.year}, styleId: ${loadedModelYear.styleId}',
                  );
                  // Перевіряємо, чи рік належить до поточного стилю
                  if (loadedModelYear.styleId == _selectedStyle!.id) {
                    modelYear = loadedModelYear;
                    // Додаємо його до списку, якщо його там немає
                    if (!_modelYears.any((my) => my.id == modelYear!.id)) {
                      setState(() {
                        _modelYears.add(modelYear!);
                      });
                    }
                  } else {
                    print(
                      'EditListingPageNew: ModelYear belongs to different style (${loadedModelYear.styleId} vs ${_selectedStyle!.id})',
                    );
                  }
                }
              }

              if (modelYear != null) {
                print('EditListingPageNew: Found modelYear: ${modelYear.year}');
                setState(() {
                  _selectedModelYear = modelYear;
                });
              } else {
                print(
                  'EditListingPageNew: ModelYear not found for id: ${widget.listing.modelYearId}',
                );
                if (_modelYears.isNotEmpty) {
                  print(
                    'EditListingPageNew: Available modelYear IDs: ${_modelYears.map((my) => my.id).toList()}',
                  );
                }
              }
            } else {
              print('EditListingPageNew: modelYearId is null');
            }
          }
        }
      }
    }
  }

  void _addFormListeners() {
    _titleController.addListener(_validateForm);
    _descriptionController.addListener(_validateForm);
    _priceController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _whatsappController.addListener(_validateForm);
    _telegramController.addListener(_validateForm);
    _viberController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _viberController.dispose();
    _citySearchController.dispose();
    _makeSearchController.dispose();
    _modelSearchController.dispose();
    _styleSearchController.dispose();
    _imagePageController.dispose();
    _radiusRController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Методи валідації
  bool _isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return true; // Поле не обов'язкове
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('380')) {
      return phone.length == 12;
    } else if (phone.startsWith('0')) {
      return phone.length == 10;
    } else {
      return phone.length >= 9 && phone.length <= 13;
    }
  }

  bool _isContactInfoValid() {
    switch (_selectedMessenger) {
      case 'phone':
        return _phoneController.text.isNotEmpty;
      case 'whatsapp':
        return _whatsappController.text.isNotEmpty;
      case 'telegram':
        return _telegramController.text.isNotEmpty;
      case 'viber':
        return _viberController.text.isNotEmpty;
      default:
        return false;
    }
  }

  bool _isPriceValid() {
    if (!_isForSale) return true; // Price is not relevant for free listings
    final cleanValue = _priceController.text.replaceAll(' ', '');
    final price = double.tryParse(cleanValue);
    return price != null && price >= 0; // Price must be a non-negative number
  }

  void _validateForm() {
    print(
      'EditListingPageNew: _validateForm called',
    ); // NEW: Log _validateForm call
    final isTitleValid = _titleController.text.isNotEmpty;
    final isDescriptionValid = _descriptionController.text.isNotEmpty;
    final isCategorySelected = _selectedCategory != null;
    final isSubcategorySelected =
        _selectedCategory?.name == 'Віддам безкоштовно' ||
        _selectedSubcategory != null;
    final isLocationSelected =
        _selectedAddress != null &&
        _selectedRegionName != null &&
        _selectedLatitude != null &&
        _selectedLongitude != null;
    final areContactInfoValid = _isContactInfoValid();
    final isPriceSectionValid = _isPriceValid();

    print('-------------------- Form Validation Log --------------------');
    print('Title Valid: $isTitleValid');
    print('Description Valid: $isDescriptionValid');
    print('Category Selected: $isCategorySelected');
    print('Subcategory Selected: $isSubcategorySelected');
    print(
      'Location Selected: $isLocationSelected (Address: $_selectedAddress, Region: $_selectedRegionName, Lat: $_selectedLatitude, Lon: $_selectedLongitude)',
    );
    print('Contact Info Valid: $areContactInfoValid');
    print(
      'Price Section Valid: $isPriceSectionValid (Is For Sale: $_isForSale, Price: ${_priceController.text})',
    );

    final overallFormValid =
        isCategorySelected &&
        isSubcategorySelected &&
        areContactInfoValid &&
        isPriceSectionValid; // Include price validation

    print('Overall Form Valid before setState: $overallFormValid');
    print('Current _isFormValid before setState: $_isFormValid');

    if (_isFormValid != overallFormValid) {
      setState(() {
        _isFormValid = overallFormValid;
        print(
          'EditListingPageNew: _isFormValid changed to: $_isFormValid',
        ); // NEW: Log when _isFormValid changes
      });
    }

    // Optionally show snackbar for contact info if not valid
    if (!areContactInfoValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Будь ласка, заповніть обраний спосіб зв\'язку'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Методи завантаження даних
  Future<void> _loadCategories() async {
    try {
      final categoryService = CategoryService();
      final categories = await categoryService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });

      // Find and select the category
      if (widget.listing.isFree) {
        _selectedCategory = categories.firstWhereOrNull(
          (cat) => cat.name == 'Віддам безкоштовно',
        );
      } else if (widget.listing.categoryId != null) {
        _selectedCategory = categories.firstWhereOrNull(
          (cat) => cat.id == widget.listing.categoryId,
        );
      }

      if (_selectedCategory != null) {
        await _loadSubcategories();
      } else {
        // Fallback to first category if original not found
        _selectedCategory = categories.firstOrNull;
        if (_selectedCategory != null) {
          await _loadSubcategories();
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadSubcategories() async {
    if (_selectedCategory == null) return;

    setState(() {
      _isLoadingSubcategories = true;
    });

    try {
      final subcategoryService = SubcategoryService(Supabase.instance.client);
      final subcategories = await subcategoryService
          .getSubcategoriesForCategory(_selectedCategory!.id);
      setState(() {
        _subcategories = subcategories;
        _isLoadingSubcategories = false;
      });

      // Find and select the subcategory
      if (_selectedCategory?.name == 'Віддам безкоштовно') {
        _selectedSubcategory = subcategories.firstWhereOrNull(
          (subcat) => subcat.name == 'Безкоштовно',
        );
      } else if (widget.listing.subcategoryId != null) {
        _selectedSubcategory = subcategories.firstWhereOrNull(
          (subcat) => subcat.id == widget.listing.subcategoryId,
        );
      }

      // Load makes if this is a car subcategory
      if (_selectedCategory?.name == 'Авто' &&
          (_selectedSubcategory?.name == 'Легкові автомобілі' ||
              _selectedSubcategory?.name == 'Автомобілі з Польщі')) {
        await _loadMakes();
        // Перевіряємо, що марки завантажені та є makeId
        if (_makes.isNotEmpty && widget.listing.makeId != null) {
          await _initializeCarFiltersFromListing();
        }
      } else {
        // Clear car filters if subcategory changed
        setState(() {
          _selectedMake = null;
          _selectedModel = null;
          _selectedStyle = null;
          _selectedModelYear = null;
          _makes.clear();
          _models.clear();
          _styles.clear();
          _modelYears.clear();
        });
      }

      _initializeExtraFields();
    } catch (e) {
      setState(() {
        _isLoadingSubcategories = false;
      });
    }
  }

  void _initializeExtraFields() {
    if (_selectedSubcategory == null) return;

    _extraFieldControllers.clear();
    _extraFieldValues.clear();

    for (var field in _selectedSubcategory!.extraFields) {
      _extraFieldControllers[field.name] = TextEditingController();

      if (widget.listing.customAttributes != null &&
          widget.listing.customAttributes!.containsKey(field.name)) {
        final value = widget.listing.customAttributes![field.name];
        if (field.type == 'number' && value is num) {
          _extraFieldControllers[field.name]!.text = value.toString();
        } else if (field.type == 'range' && value is Map) {
          if (value['min'] != null) {
            _extraFieldControllers['${field.name}_min'] = TextEditingController(
              text: value['min'].toString(),
            );
          }
          if (value['max'] != null) {
            _extraFieldControllers['${field.name}_max'] = TextEditingController(
              text: value['max'].toString(),
            );
          }
        } else if (field.type == 'select' && value != null) {
          _extraFieldValues[field.name] = value.toString();
        }
      }
    }
  }

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

  Future<void> _loadRegions() async {
    try {
      final regionService = RegionService(Supabase.instance.client);
      final regions = await regionService.getRegions();

      // Сортуємо області в алфавітному порядку з урахуванням українського алфавіту
      final sortedRegions = List<Region>.from(regions)
        ..sort((a, b) => _compareUkrainianStrings(a.name, b.name));

      setState(() {
        _regions = sortedRegions;
        _isLoadingRegions = false;
      });

      if (widget.listing.region != null) {
        _selectedRegion = sortedRegions.firstWhere(
          (region) => region.name == widget.listing.region,
          orElse: () => sortedRegions.first,
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingRegions = false;
      });
    }
  }

  void _showBlockedUserBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BlockedUserBottomSheet(),
    );
  }

  // Метод оновлення оголошення
  Future<void> _updateListing() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final listingService = ListingService(Supabase.instance.client);

        Map<String, dynamic>? customAttributes;
        if (_selectedSubcategory != null && _extraFieldValues.isNotEmpty) {
          customAttributes = {};
          for (var field in _selectedSubcategory!.extraFields) {
            if (field.type == 'number') {
              final value = double.tryParse(
                _extraFieldControllers[field.name]?.text ?? '',
              );
              if (value != null) {
                customAttributes[field.name] = value;
              }
            } else if (field.type == 'range') {
              final minValue = double.tryParse(
                _extraFieldControllers['${field.name}_min']?.text ?? '',
              );
              final maxValue = double.tryParse(
                _extraFieldControllers['${field.name}_max']?.text ?? '',
              );
              if (minValue != null || maxValue != null) {
                customAttributes[field.name] = {
                  'min': minValue,
                  'max': maxValue,
                };
              }
            } else if (field.type == 'select') {
              customAttributes[field.name] = _extraFieldValues[field.name];
            }
          }
        }

        final List<String> existingImageUrls = _selectedImages
            .whereType<String>()
            .toList();
        final List<XFile> newImagesToUpload = _selectedImages
            .whereType<XFile>()
            .toList();

        String locationString = '';
        if (_selectedRegion != null) {
          locationString = _selectedRegion!.name;
        } else if (_selectedRegionName != null) {
          locationString = _selectedRegionName!;
        } else {
          locationString = widget.listing.location;
        }

        await listingService.updateListing(
          listingId: widget.listing.id,
          title: _titleController.text,
          description: _descriptionController.text,
          categoryId: _selectedCategory?.id ?? widget.listing.categoryId,
          subcategoryId:
              _selectedSubcategory?.id ?? widget.listing.subcategoryId,
          location: locationString,
          isFree: !_isForSale,
          currency: _isForSale ? _selectedCurrency : null,
          price: _isForSale ? double.tryParse(_priceController.text.replaceAll(' ', '')) : null,
          phoneNumber:
              _selectedMessenger == 'phone' && _phoneController.text.isNotEmpty
              ? '+380${_phoneController.text}'
              : null,
          whatsapp:
              _selectedMessenger == 'whatsapp' &&
                  _whatsappController.text.isNotEmpty
              ? '+380${_whatsappController.text}'
              : null,
          telegram:
              _selectedMessenger == 'telegram' &&
                  _telegramController.text.isNotEmpty
              ? '+380${_telegramController.text}'
              : null,
          viber:
              _selectedMessenger == 'viber' && _viberController.text.isNotEmpty
              ? '+380${_viberController.text}'
              : null,
          customAttributes: customAttributes ?? {},
          newImages: newImagesToUpload,
          existingImageUrls: existingImageUrls,
          address: _selectedAddress,
          region: _selectedRegionName,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          realEstateType: _selectedCategory?.name == 'Нерухомість'
              ? _realEstateType
              : null,
          jobType: _selectedCategory?.name == 'Робота' ? _jobType : null,
          helpType: _selectedCategory?.name == 'Допомога' ? _helpType : null,
          giveawayType: _selectedCategory?.name == 'Віддам безкоштовно'
              ? _giveawayType
              : null,
          conditionType:
              _selectedCategory?.name == 'Одяг та аксесуари' ||
                  _selectedCategory?.name == 'Дитячий світ'
              ? _conditionType
              : null,
          size: _selectedCategory?.name == 'Одяг та аксесуари'
              ? _selectedSize
              : null,
          radiusR:
              _selectedCategory?.name == 'Запчастини для транспорту' &&
                  _selectedSubcategory?.name == 'Шини, диски і колеса' &&
                  _radiusRController.text.isNotEmpty
              ? double.tryParse(_radiusRController.text)
              : null,
          genderType: _selectedCategory?.name == 'Дитячий світ'
              ? _genderType
              : null,
          makeId:
              _selectedCategory?.name == 'Авто' &&
                  (_selectedSubcategory?.name == 'Легкові автомобілі' ||
                      _selectedSubcategory?.name == 'Автомобілі з Польщі')
              ? _selectedMake?.id
              : null,
          modelId:
              _selectedCategory?.name == 'Авто' &&
                  (_selectedSubcategory?.name == 'Легкові автомобілі' ||
                      _selectedSubcategory?.name == 'Автомобілі з Польщі')
              ? _selectedModel?.id
              : null,
          styleId:
              _selectedCategory?.name == 'Авто' &&
                  (_selectedSubcategory?.name == 'Легкові автомобілі' ||
                      _selectedSubcategory?.name == 'Автомобілі з Польщі')
              ? _selectedStyle?.id
              : null,
          modelYearId:
              _selectedCategory?.name == 'Авто' &&
                  (_selectedSubcategory?.name == 'Легкові автомобілі' ||
                      _selectedSubcategory?.name == 'Автомобілі з Польщі')
              ? _selectedModelYear?.id
              : null,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        // Помилка оновлення оголошення
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return wrapWithKeyboardDismisser(
      Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          elevation: 0.0,
          scrolledUnderElevation: 0.0,
          toolbarHeight: 70.0,
          centerTitle: false,
          leading: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Icon(Icons.arrow_back, color: AppColors.color2, size: 24),
          ),
          title: Text(
            'Редагувати оголошення',
            style: AppTextStyles.heading2Semibold.copyWith(
              color: AppColors.color2,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Listener(
                    onPointerDown: (event) {
                      if (_isMakeOpen ||
                          _isModelOpen ||
                          _isStyleOpen ||
                          _isModelYearOpen) {
                        if (!_isTapInsideCarDropdown(event.position)) {
                          setState(() {
                            _isMakeOpen = false;
                            _isModelOpen = false;
                            _isStyleOpen = false;
                            _isModelYearOpen = false;
                          });
                        }
                      }
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13.0,
                        vertical: 20.0,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 1, color: AppColors.zinc200),
                            const SizedBox(height: 20),

                            // Photos Section
                            _buildPhotosSection(),
                            const SizedBox(height: 20),

                            // Title Input Field
                            Text(
                              'Заголовок',
                              style: AppTextStyles.body2Medium.copyWith(
                                color: AppColors.color8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.zinc50,
                                borderRadius: BorderRadius.circular(200),
                                border: Border.all(
                                  color: AppColors.zinc200,
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(16, 24, 40, 0.05),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _titleController,
                                style: AppTextStyles.body1Regular.copyWith(
                                  color: AppColors.color2,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Введіть текст',
                                  hintStyle: AppTextStyles.body1Regular
                                      .copyWith(color: AppColors.color5),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Description Input Field
                            Text(
                              'Опис',
                              style: AppTextStyles.body2Medium.copyWith(
                                color: AppColors.color8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 180,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.zinc50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.zinc200,
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(16, 24, 40, 0.05),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _descriptionController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: AppTextStyles.body1Regular.copyWith(
                                  color: AppColors.color2,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Введіть текст',
                                  hintStyle: AppTextStyles.body1Regular
                                      .copyWith(color: AppColors.color5),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Category Section
                            _buildCategorySection(),
                            const SizedBox(height: 20),

                            // Subcategory Section
                            _buildSubcategorySection(),

                            // Car brand selector (for Легкові автомобілі and Автомобілі з Польщі)
                            // Показуємо одразу після підкатегорії
                            _buildCarBrandSelector(),
                            if (_selectedCategory?.name == 'Авто' &&
                                (_selectedSubcategory?.name ==
                                        'Легкові автомобілі' ||
                                    _selectedSubcategory?.name ==
                                        'Автомобілі з Польщі'))
                              const SizedBox(height: 20),

                            // Spacing before category-specific toggles
                            if (_selectedCategory?.name == 'Нерухомість' ||
                                _selectedCategory?.name == 'Робота' ||
                                _selectedCategory?.name == 'Допомога' ||
                                _selectedCategory?.name ==
                                    'Віддам безкоштовно' ||
                                _selectedCategory?.name ==
                                    'Одяг та аксесуари' ||
                                _selectedCategory?.name == 'Дитячий світ')
                              const SizedBox(height: 20),

                            // Real Estate Type Toggle
                            if (_selectedCategory?.name == 'Нерухомість' &&
                                _selectedSubcategory != null)
                              _buildRealEstateTypeToggle(),

                            // Job Type Toggle
                            if (_selectedCategory?.name == 'Робота')
                              _buildJobTypeToggle(),

                            // Help Type Toggle
                            if (_selectedCategory?.name == 'Допомога')
                              _buildHelpTypeToggle(),

                            // Giveaway Type Toggle
                            if (_selectedCategory?.name == 'Віддам безкоштовно')
                              _buildGiveawayTypeToggle(),

                            // Condition Type Toggle
                            if (_selectedCategory?.name ==
                                    'Одяг та аксесуари' ||
                                _selectedCategory?.name == 'Дитячий світ')
                              _buildConditionTypeToggle(),

                            const SizedBox(height: 20), // Add spacing here
                            // Size Selection
                            if (_selectedCategory?.name == 'Одяг та аксесуари')
                              _buildSizeSelection(),

                            // Radius R Input
                            if (_selectedCategory?.name ==
                                    'Запчастини для транспорту' &&
                                _selectedSubcategory?.name ==
                                    'Шини, диски і колеса')
                              _buildRadiusRInput(),

                            // Gender Type Toggle (for Children's World)
                            if (_selectedCategory?.name == 'Дитячий світ')
                              _buildGenderTypeToggle(),

                            const SizedBox(height: 20),

                            // LocationCreationBlock
                            LocationCreationBlock(
                              initialLocation:
                                  _selectedLatitude != null &&
                                      _selectedLongitude != null
                                  ? latlong.LatLng(
                                      _selectedLatitude!,
                                      _selectedLongitude!,
                                    )
                                  : null,
                              initialRegion: _selectedRegionName,
                              initialCity:
                                  _selectedCity?.name, // NEW: Pass initialCity
                              onLocationSelected:
                                  (
                                    latLng,
                                    address,
                                    regionName,
                                    cityName,
                                  ) async {
                                    if (latLng != null) {
                                      Region? foundRegion;
                                      if (regionName != null) {
                                        foundRegion = _regions.firstWhereOrNull(
                                          (region) => region.name == regionName,
                                        );
                                      }

                                      if (foundRegion == null) {
                                        double shortestDistance =
                                            double.infinity;
                                        for (final region in _regions) {
                                          if (region.minLat != null &&
                                              region.maxLat != null &&
                                              region.minLon != null &&
                                              region.maxLon != null) {
                                            final centerLat =
                                                (region.minLat! +
                                                    region.maxLat!) /
                                                2;
                                            final centerLon =
                                                (region.minLon! +
                                                    region.maxLon!) /
                                                2;

                                            final distance =
                                                Geolocator.distanceBetween(
                                                  latLng.latitude,
                                                  latLng.longitude,
                                                  centerLat,
                                                  centerLon,
                                                );

                                            if (distance < shortestDistance) {
                                              shortestDistance = distance;
                                              foundRegion = region;
                                            }
                                          }
                                        }
                                      }

                                      setState(() {
                                        _selectedRegion = foundRegion;
                                        _selectedRegionName =
                                            foundRegion?.name ?? regionName;
                                        _selectedCity = cityName != null
                                            ? City(
                                                name: cityName,
                                                regionId: regionName ?? '',
                                              )
                                            : null;
                                        _selectedLatitude = latLng.latitude;
                                        _selectedLongitude = latLng.longitude;
                                        _selectedAddress =
                                            address ?? 'Обрана локація';
                                      });
                                      _validateForm(); // NEW: Validate form after location selected
                                    }
                                  },
                            ),
                            const SizedBox(height: 20),

                            // Listing Type Toggle
                            if (_selectedCategory?.name !=
                                    'Віддам безкоштовно' &&
                                !(_selectedCategory?.name == 'Нерухомість' &&
                                    _selectedSubcategory != null) &&
                                _selectedCategory?.name != 'Робота' &&
                                _selectedCategory?.name != 'Допомога' &&
                                _selectedCategory?.name !=
                                    'Одяг та аксесуари' &&
                                _selectedCategory?.name != 'Дитячий світ') ...[
                              _buildListingTypeToggle(),
                              const SizedBox(height: 20),
                            ],

                            // Currency Switch - only show if not free
                            if (_isForSale) ...[
                              _buildCurrencySection(),
                              const SizedBox(height: 20),
                            ],

                            // Price Input Field - only show if not free
                            if (_isForSale) ...[
                              _buildPriceSection(),
                              const SizedBox(height: 20),
                            ],

                            // Contact Form Section
                            _buildContactForm(),
                            const SizedBox(height: 20),

                            // Extra fields section
                            _buildExtraFieldsSection(),
                            const SizedBox(height: 20),

                            // Add bottom padding to account for floating buttons
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Floating buttons
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13.0,
                        vertical: 20.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isFormValid
                                  ? () {
                                      print(
                                        'EditListingPageNew: "Зберегти зміни" button pressed. Form is valid: $_isFormValid',
                                      ); // NEW: Log button press
                                      _updateListing();
                                    }
                                  : null, // Conditionally enable button
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Зберегти зміни',
                                style: AppTextStyles.body2Semibold.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: BorderSide(color: AppColors.zinc200),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Скасувати',
                                style: AppTextStyles.body2Semibold.copyWith(
                                  color: AppColors.color8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Додайте фото',
              style: AppTextStyles.body2Medium.copyWith(
                color: AppColors.color8,
              ),
            ),
            Text(
              '${_selectedImages.length}/7',
              style: AppTextStyles.captionMedium.copyWith(
                color: AppColors.color5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: AppColors.zinc200,
              strokeWidth: 1.0,
              dashWidth: 13.0,
              gapWidth: 13.0,
              borderRadius: 12.0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.zinc50,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(16, 24, 40, 0.05),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Center(
                    child: SvgPicture.asset(
                      'assets/icons/Featured icon.svg',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Перемістіть зображення',
                    style: AppTextStyles.body1Medium.copyWith(
                      color: AppColors.color2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PNG, JPG (max. 200MB)',
                    style: AppTextStyles.captionRegular.copyWith(
                      color: AppColors.color8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(_selectedImages.length, (index) {
                final image = _selectedImages[index];
                return SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImageWidget(image),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                            _validateForm();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      if (_selectedImages.length >= 7) {
        return;
      }

      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        // Validate each image before adding
        for (var image in images) {
          try {
            // Verify the image can be read
            await image.readAsBytes();

            if (_selectedImages.length < 7) {
              setState(() {
                _selectedImages.add(image);
              });
              _validateForm();
            }
          } catch (e) {
            // Skip invalid image
          }
        }
      }
    } catch (e) {
      // Error selecting images
    }
  }

  Widget _buildImageWidget(dynamic image) {
    if (image is String) {
      // Це URL зображення (існуюче зображення)
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.zinc200,
            child: Icon(Icons.error, color: AppColors.color5),
          );
        },
      );
    } else if (image is XFile) {
      // Це нове зображення
      if (kIsWeb) {
        return Image.network(
          image.path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.zinc200,
              child: Icon(Icons.error, color: AppColors.color5),
            );
          },
        );
      }
      return Image.file(
        File(image.path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.zinc200,
            child: Icon(Icons.error, color: AppColors.color5),
          );
        },
      );
    }
    return Container(
      color: AppColors.zinc200,
      child: Icon(Icons.error, color: AppColors.color5),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Категорія',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _categoryButtonKey,
          onTap: () {
            final RenderBox? button =
                _categoryButtonKey.currentContext?.findRenderObject()
                    as RenderBox?;
            if (button != null) {
              final buttonPosition = button.localToGlobal(Offset.zero);
              final buttonSize = button.size;

              _showCategoryPicker(position: buttonPosition, size: buttonSize);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedCategory?.name ?? 'Оберіть категорію',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedCategory != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                SvgPicture.asset(
                  'assets/icons/chevron_down.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.color7,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategorySection() {
    if (_selectedCategory == null ||
        _selectedCategory!.name == 'Віддам безкоштовно') {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Підкатегорія',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _subcategoryButtonKey,
          onTap: _selectedCategory == null
              ? null
              : () {
                  final RenderBox? button =
                      _subcategoryButtonKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (button != null) {
                    final buttonPosition = button.localToGlobal(Offset.zero);
                    final buttonSize = button.size;

                    _showSubcategoryPicker(
                      position: buttonPosition,
                      size: buttonSize,
                    );
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _selectedCategory == null
                  ? AppColors.zinc100
                  : AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedSubcategory?.name ?? 'Оберіть підкатегорію',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedSubcategory != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                SvgPicture.asset(
                  'assets/icons/chevron_down.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.color7,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListingTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тип оголошення',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isForSale = true;
                    });
                    _validateForm(); // NEW: Validate form after toggle
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _isForSale
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Продати',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _isForSale ? Colors.white : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isForSale = false;
                    });
                    _validateForm(); // NEW: Validate form after toggle
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: !_isForSale
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Безкоштовно',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: !_isForSale ? Colors.white : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencySection() {
    if (!_isForSale) {
      return const SizedBox.shrink(); // Hide currency section if not for sale
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Валюта',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(200)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = 'UAH';
                    });
                    _validateForm(); // NEW: Validate form after currency change
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedCurrency == 'UAH'
                          ? AppColors.primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(200),
                      border: Border.all(
                        color: _selectedCurrency == 'UAH'
                            ? AppColors.primaryColor
                            : AppColors.zinc200,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(16, 24, 40, 0.05),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/currency-grivna-svgrepo-com 1.svg',
                          width: 21,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            _selectedCurrency == 'UAH'
                                ? Colors.white
                                : AppColors.color5,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ГРН',
                          style: AppTextStyles.body2Semibold.copyWith(
                            color: _selectedCurrency == 'UAH'
                                ? Colors.white
                                : AppColors.color8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = 'EUR';
                    });
                    _validateForm(); // NEW: Validate form after currency change
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedCurrency == 'EUR'
                          ? AppColors.primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(200),
                      border: Border.all(
                        color: _selectedCurrency == 'EUR'
                            ? AppColors.primaryColor
                            : AppColors.zinc200,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(16, 24, 40, 0.05),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/currency-euro.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            _selectedCurrency == 'EUR'
                                ? Colors.white
                                : AppColors.color5,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EUR',
                          style: AppTextStyles.body2Semibold.copyWith(
                            color: _selectedCurrency == 'EUR'
                                ? Colors.white
                                : AppColors.color8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = 'USD';
                    });
                    _validateForm(); // NEW: Validate form after currency change
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedCurrency == 'USD'
                          ? AppColors.primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(200),
                      border: Border.all(
                        color: _selectedCurrency == 'USD'
                            ? AppColors.primaryColor
                            : AppColors.zinc200,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(16, 24, 40, 0.05),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/currency-dollar.svg',
                          width: 21,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            _selectedCurrency == 'USD'
                                ? Colors.white
                                : AppColors.color5,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'USD',
                          style: AppTextStyles.body2Semibold.copyWith(
                            color: _selectedCurrency == 'USD'
                                ? Colors.white
                                : AppColors.color8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    if (!_isForSale) {
      return const SizedBox.shrink(); // Hide price section if not for sale
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedCategory?.name == 'Нерухомість' && _realEstateType == 'rent'
              ? 'Ціна за місяць'
              : 'Ціна',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
            PriceInputFormatter(),
          ],
          decoration: InputDecoration(
            hintText: 'Введіть ціну',
            hintStyle: AppTextStyles.body1Regular.copyWith(
              color: AppColors.color7,
            ),
            filled: true,
            fillColor: AppColors.zinc50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(200),
              borderSide: BorderSide(color: AppColors.zinc200, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(200),
              borderSide: BorderSide(color: AppColors.zinc200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(200),
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1),
            ),
          ),
          style: AppTextStyles.body1Regular.copyWith(color: AppColors.color2),
        ),
      ],
    );
  }

  Widget _buildContactForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Контактна форма',
          style: AppTextStyles.body1Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 4),
        Text(
          'Оберіть спосіб зв\'язку',
          style: AppTextStyles.body2Regular.copyWith(color: AppColors.color5),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMessengerButton(
                type: 'whatsapp',
                iconPath: 'assets/icons/whatsapp.svg',
                label: '',
              ),
              const SizedBox(width: 8),
              _buildMessengerButton(
                type: 'telegram',
                iconPath: 'assets/icons/telegram.svg',
                label: '',
              ),
              const SizedBox(width: 8),
              _buildMessengerButton(
                type: 'viber',
                iconPath: 'assets/icons/viber.svg',
                label: '',
              ),
              const SizedBox(width: 8),
              _buildMessengerButton(
                type: 'phone',
                iconPath: 'assets/icons/phone.svg',
                label: '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedMessenger == 'phone')
          _buildPhoneInput(
            controller: _phoneController,
            hintText: '(XX) XXX-XX-XX',
          )
        else if (_selectedMessenger == 'whatsapp')
          _buildPhoneInput(
            controller: _whatsappController,
            hintText: '(XX) XXX-XX-XX',
          )
        else if (_selectedMessenger == 'telegram')
          _buildPhoneInput(
            controller: _telegramController,
            hintText: '(XX) XXX-XX-XX',
          )
        else if (_selectedMessenger == 'viber')
          _buildPhoneInput(
            controller: _viberController,
            hintText: '(XX) XXX-XX-XX',
          ),
      ],
    );
  }

  Widget _buildMessengerButton({
    required String type,
    required String iconPath,
    required String label,
  }) {
    final bool isSelected = _selectedMessenger == type;
    final bool isSocialIcon =
        type == 'whatsapp' || type == 'telegram' || type == 'viber';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMessenger = type;
          // Clear non-selected contact fields when switching method
          if (type != 'phone') _phoneController.clear();
          if (type != 'whatsapp') _whatsappController.clear();
          if (type != 'telegram') _telegramController.clear();
          if (type != 'viber') _viberController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : AppColors.zinc100,
          borderRadius: BorderRadius.circular(200),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : AppColors.zinc100,
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0C101828),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: SvgPicture.asset(
          iconPath,
          width: 20,
          height: 20,
          colorFilter: isSocialIcon
              ? null
              : ColorFilter.mode(
                  isSelected ? Colors.white : AppColors.color5,
                  BlendMode.srcIn,
                ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput({
    required TextEditingController controller,
    required String hintText,
    bool isTelegramInput = false,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.zinc50,
        borderRadius: BorderRadius.circular(200),
        border: Border.all(color: AppColors.zinc200),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(16, 24, 40, 0.05),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isTelegramInput) ...[
            const SizedBox(width: 16),
            // Прапор України
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0057B8),
              ),
              child: ClipOval(
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF0057B8)),
                    ),
                    Container(
                      width: 20,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFFFFD700)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Префікс +380
            Text(
              '+380',
              style: AppTextStyles.body1Regular.copyWith(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                keyboardType: isTelegramInput
                    ? TextInputType.text
                    : TextInputType.phone,
                inputFormatters: _getContactInputFormatters(),
                decoration: InputDecoration(
                  hintText: isTelegramInput ? hintText : '(XX) XXX-XX-XX',
                  hintStyle: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color5,
                  ),
                  contentPadding: EdgeInsets.only(
                    left: isTelegramInput ? 16 : 0,
                    right: 16,
                    top: 0,
                    bottom: 0,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: AppTextStyles.body1Regular.copyWith(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextInputFormatter> _getContactInputFormatters() {
    switch (_selectedMessenger) {
      case 'phone':
      case 'whatsapp':
      case 'viber':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9), // Обмеження до 9 цифр (без +380)
        ];
      case 'telegram':
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(
            9,
          ), // Телеграм як номер телефону (без +380)
        ];
      default:
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ];
    }
  }

  Widget _buildCarBrandSelector() {
    // Показуємо селектор марки авто тільки для категорії "Авто" та підкатегорій "Легкові автомобілі" та "Автомобілі з Польщі"
    if (_selectedCategory?.name != 'Авто') return const SizedBox.shrink();
    if (_selectedSubcategory?.name != 'Легкові автомобілі' &&
        _selectedSubcategory?.name != 'Автомобілі з Польщі')
      return const SizedBox.shrink();

    return Column(
      children: [
        // Марка
        _buildMakeSelector(),
        // Модель
        if (_selectedMake != null) ...[
          const SizedBox(height: 20),
          _buildModelSelector(),
        ],
        // Стиль
        if (_selectedModel != null) ...[
          const SizedBox(height: 20),
          _buildStyleSelector(),
        ],
        // Рік випуску
        if (_selectedStyle != null) ...[
          const SizedBox(height: 20),
          _buildModelYearSelector(),
        ],
      ],
    );
  }

  bool _isTapInsideCarDropdown(Offset globalPosition) {
    bool check(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return false;
      final topLeft = box.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        box.size.width,
        box.size.height,
      ).contains(globalPosition);
    }

    if (_isMakeOpen && check(_makeSelectorKey)) return true;
    if (_isModelOpen && check(_modelSelectorKey)) return true;
    if (_isStyleOpen && check(_styleSelectorKey)) return true;
    if (_isModelYearOpen && check(_modelYearSelectorKey)) return true;
    return false;
  }

  List<Make> get _filteredMakes {
    final q = _makeSearchController.text.toLowerCase().trim();
    if (q.isEmpty) return _makes;
    return _makes.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  List<Model> get _filteredModels {
    final q = _modelSearchController.text.toLowerCase().trim();
    if (q.isEmpty) return _models;
    return _models.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  List<Style> get _filteredStyles {
    final q = _styleSearchController.text.toLowerCase().trim();
    if (q.isEmpty) return _styles;
    return _styles.where((s) => s.styleName.toLowerCase().contains(q)).toList();
  }

  Widget _buildMakeSelector() {
    return Column(
      key: _makeSelectorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Марка',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _makeKey,
          onTap: () {
            setState(() {
              _isMakeOpen = !_isMakeOpen;
              _isModelOpen = false;
              _isStyleOpen = false;
              _isModelYearOpen = false;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedMake?.name ?? 'Оберіть марку',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedMake != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingMakes)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isMakeOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _makeSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Пошук...',
                      hintStyle: AppTextStyles.body2Regular.copyWith(
                        color: AppColors.color5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.color5,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                    ),
                    style: AppTextStyles.body2Regular,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _filteredMakes.length,
                    itemBuilder: (context, index) {
                      final make = _filteredMakes[index];
                      return _buildMakeItem(make);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMakeItem(Make make) {
    final isSelected = _selectedMake?.id == make.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMake = make;
            _selectedModel = null;
            _selectedStyle = null;
            _selectedModelYear = null;
            _isMakeOpen = false;
            _makeSearchController.clear();
            _models.clear();
            _styles.clear();
            _modelYears.clear();
          });
          _loadModels(make.id);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  make.name,
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Column(
      key: _modelSelectorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Модель',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _modelKey,
          onTap: () {
            setState(() {
              _isModelOpen = !_isModelOpen;
              _isStyleOpen = false;
              _isModelYearOpen = false;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedModel?.name ?? 'Оберіть модель',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedModel != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingModels)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isModelOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _modelSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Пошук...',
                      hintStyle: AppTextStyles.body2Regular.copyWith(
                        color: AppColors.color5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.color5,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                    ),
                    style: AppTextStyles.body2Regular,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount:
                        _filteredModels.length +
                        (_selectedModel != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_selectedModel != null && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedModel = null;
                                _selectedStyle = null;
                                _selectedModelYear = null;
                                _isModelOpen = false;
                                _styles.clear();
                                _modelYears.clear();
                                _modelSearchController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: AppColors.color5,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Очистити',
                                    style: AppTextStyles.body2Regular.copyWith(
                                      color: AppColors.color5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final model =
                          _filteredModels[_selectedModel != null
                              ? index - 1
                              : index];
                      return _buildModelItem(model);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModelItem(Model model) {
    final isSelected = _selectedModel?.id == model.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedModel = model;
            _selectedStyle = null;
            _selectedModelYear = null;
            _isModelOpen = false;
            _modelSearchController.clear();
            _styles.clear();
            _modelYears.clear();
          });
          _loadStyles(model.id);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Column(
      key: _styleSelectorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Підмодель / Стиль',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _styleKey,
          onTap: () {
            setState(() {
              _isStyleOpen = !_isStyleOpen;
              _isModelYearOpen = false;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedStyle != null
                        ? '${_selectedStyle!.styleName}${_selectedStyle!.fuelType != null ? ' (${_selectedStyle!.fuelType})' : ''}'
                        : 'Оберіть підмодель / стиль',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedStyle != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingStyles)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isStyleOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _styleSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Пошук...',
                      hintStyle: AppTextStyles.body2Regular.copyWith(
                        color: AppColors.color5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.color5,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.zinc200),
                      ),
                    ),
                    style: AppTextStyles.body2Regular,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount:
                        _filteredStyles.length +
                        (_selectedStyle != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_selectedStyle != null && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedStyle = null;
                                _selectedModelYear = null;
                                _isStyleOpen = false;
                                _modelYears.clear();
                                _styleSearchController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: AppColors.color5,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Очистити',
                                    style: AppTextStyles.body2Regular.copyWith(
                                      color: AppColors.color5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final style =
                          _filteredStyles[_selectedStyle != null
                              ? index - 1
                              : index];
                      return _buildStyleItem(style);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStyleItem(Style style) {
    final isSelected = _selectedStyle?.id == style.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStyle = style;
            _selectedModelYear = null;
            _isStyleOpen = false;
            _styleSearchController.clear();
            _modelYears.clear();
          });
          _loadModelYears(style.id);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${style.styleName}${style.fuelType != null ? ' (${style.fuelType})' : ''}',
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelYearSelector() {
    return Column(
      key: _modelYearSelectorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Рік випуску',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _modelYearKey,
          onTap: () {
            setState(() {
              _isModelYearOpen = !_isModelYearOpen;
            });
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(color: AppColors.zinc200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.05),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedModelYear != null
                        ? '${_selectedModelYear!.year}'
                        : 'Оберіть рік випуску',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedModelYear != null
                          ? AppColors.color2
                          : AppColors.color5,
                    ),
                  ),
                ),
                if (_isLoadingModelYears)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/chevron_down.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.color7,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isModelYearOpen)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.zinc200),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: _modelYears.length,
              itemBuilder: (context, index) {
                final modelYear = _modelYears[index];
                return _buildModelYearItem(modelYear);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildModelYearItem(ModelYear modelYear) {
    final isSelected = _selectedModelYear?.id == modelYear.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedModelYear = modelYear;
            _isModelYearOpen = false;
          });
          _validateForm();
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.zinc50 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${modelYear.year}',
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.primaryColor,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtraFieldsSection() {
    if (_selectedSubcategory == null ||
        _selectedSubcategory!.extraFields.isEmpty) {
      return const SizedBox.shrink();
    }

    // Фільтруємо поля, які не повинні відображатися (вони мають свої спеціальні UI компоненти)
    final filteredFields = _selectedSubcategory!.extraFields
        .where(
          (field) =>
              field.name != 'area' &&
              field.name != 'square_meters' &&
              field.name != 'rooms' &&
              field.name != 'year' &&
              field.name != 'car_brand' &&
              field.name != 'engine_power' &&
              field.name != 'engine_power_hp' &&
              field.name != 'size' &&
              field.name != 'condition' &&
              field.name != 'age_range',
        )
        .toList();

    if (filteredFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Додаткові характеристики',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 12),
        ...filteredFields.map((field) => _buildExtraField(field)),
      ],
    );
  }

  Widget _buildExtraField(dynamic field) {
    switch (field.type) {
      case 'number':
        return _buildNumberField(field);
      case 'range':
        return _buildRangeField(field);
      case 'select':
        return _buildSelectField(field);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNumberField(dynamic field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.name,
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(16, 24, 40, 0.05),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: TextField(
            controller: _extraFieldControllers[field.name],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.body1Regular.copyWith(color: AppColors.color2),
            decoration: InputDecoration(
              hintText: 'Введіть значення',
              hintStyle: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color5,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRangeField(dynamic field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.name,
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.zinc50,
                  borderRadius: BorderRadius.circular(200),
                  border: Border.all(color: AppColors.zinc200, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(16, 24, 40, 0.05),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _extraFieldControllers['${field.name}_min'],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Мін',
                    hintStyle: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.zinc50,
                  borderRadius: BorderRadius.circular(200),
                  border: Border.all(color: AppColors.zinc200, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(16, 24, 40, 0.05),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _extraFieldControllers['${field.name}_max'],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Макс',
                    hintStyle: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSelectField(dynamic field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.name,
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(16, 24, 40, 0.05),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _extraFieldValues[field.name],
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            hint: Text(
              'Оберіть значення',
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color5,
              ),
            ),
            items: field.options.map<DropdownMenuItem<String>>((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _extraFieldValues[field.name] = newValue;
              });
              _validateForm(); // NEW: Validate form after extra field change
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showCategoryPicker({required Offset position, required Size size}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned(
              top: position.dy + size.height + 4,
              left: position.dx,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.zinc200),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(16, 24, 40, 0.03),
                        offset: Offset(0, 4),
                        blurRadius: 6,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            return ListTile(
                              title: Text(
                                category.name,
                                style: AppTextStyles.body1Regular.copyWith(
                                  color: AppColors.color2,
                                ),
                              ),
                              onTap: () async {
                                setState(() {
                                  _selectedCategory = category;
                                  _selectedSubcategory = null;
                                  _subcategories.clear();
                                  _extraFieldControllers.clear();
                                  _extraFieldValues.clear();
                                });

                                await _loadSubcategories(); // Load subcategories first

                                if (category.name == 'Віддам безкоштовно') {
                                  setState(() {
                                    _isForSale = false; // Set to free
                                    _priceController.clear(); // Clear price
                                    _selectedCurrency = 'UAH'; // Reset currency
                                    _isNegotiablePrice =
                                        false; // Reset negotiable
                                    final freeSubcategory = _subcategories
                                        .firstWhereOrNull(
                                          (sub) => sub.name == 'Безкоштовно',
                                        );
                                    if (freeSubcategory != null) {
                                      _selectedSubcategory = freeSubcategory;
                                    }
                                  });
                                } else if (category.name == 'Робота') {
                                  setState(() {
                                    _isForSale =
                                        false; // Job is not for sale in a typical sense
                                    _priceController.clear();
                                  });
                                } else if (category.name == 'Допомога') {
                                  setState(() {
                                    _isForSale = false; // Help is not for sale
                                    _priceController.clear();
                                  });
                                } else {
                                  setState(() {
                                    _isForSale = true; // Default to for sale
                                  });
                                }
                                _validateForm(); // NEW: Validate form after category change
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSubcategoryPicker({required Offset position, required Size size}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned(
              top: position.dy + size.height + 4,
              left: position.dx,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.zinc200),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(16, 24, 40, 0.03),
                        offset: Offset(0, 4),
                        blurRadius: 6,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _subcategories.length,
                          itemBuilder: (context, index) {
                            final subcategory = _subcategories[index];
                            return ListTile(
                              title: Text(
                                subcategory.name,
                                style: AppTextStyles.body1Regular.copyWith(
                                  color: AppColors.color2,
                                ),
                              ),
                              onTap: () async {
                                setState(() {
                                  _selectedSubcategory = subcategory;
                                  _extraFieldControllers.clear();
                                  _extraFieldValues.clear();
                                  // Clear car filters if subcategory changed
                                  if (_selectedCategory?.name != 'Авто' ||
                                      (subcategory.name !=
                                              'Легкові автомобілі' &&
                                          subcategory.name !=
                                              'Автомобілі з Польщі')) {
                                    _selectedMake = null;
                                    _selectedModel = null;
                                    _selectedStyle = null;
                                    _selectedModelYear = null;
                                    _makes.clear();
                                    _models.clear();
                                    _styles.clear();
                                    _modelYears.clear();
                                  }
                                });
                                // Load makes if this is a car subcategory
                                if (_selectedCategory?.name == 'Авто' &&
                                    (subcategory.name == 'Легкові автомобілі' ||
                                        subcategory.name ==
                                            'Автомобілі з Польщі')) {
                                  await _loadMakes();
                                  // Перевіряємо, що марки завантажені та є makeId
                                  if (_makes.isNotEmpty &&
                                      widget.listing.makeId != null) {
                                    await _initializeCarFiltersFromListing();
                                  }
                                }
                                _initializeExtraFields();
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
                                _validateForm(); // NEW: Validate form after subcategory change
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _extractCityFromAddress(String? address) {
    if (address == null || address.isEmpty) {
      return null;
    }
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      return parts[0].trim();
    }
    return null;
  }

  Widget _buildRealEstateTypeToggle() {
    if (_selectedCategory?.name != 'Нерухомість' ||
        _selectedSubcategory == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Тип угоди',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(16, 24, 40, 0.05),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _realEstateType = 'sale');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _realEstateType == 'sale'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                      border: Border.all(
                        color: _realEstateType == 'sale'
                            ? AppColors.zinc200
                            : Colors.transparent,
                        width: 1,
                      ),
                      boxShadow: _realEstateType == 'sale'
                          ? const [
                              BoxShadow(
                                color: Color.fromRGBO(16, 24, 40, 0.05),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      'Продаж',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Semibold.copyWith(
                        color: _realEstateType == 'sale'
                            ? AppColors.color2
                            : AppColors.color7,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _realEstateType = 'rent');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _realEstateType == 'rent'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                      border: Border.all(
                        color: _realEstateType == 'rent'
                            ? AppColors.zinc200
                            : Colors.transparent,
                        width: 1,
                      ),
                      boxShadow: _realEstateType == 'rent'
                          ? const [
                              BoxShadow(
                                color: Color.fromRGBO(16, 24, 40, 0.05),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      'Оренда',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Semibold.copyWith(
                        color: _realEstateType == 'rent'
                            ? AppColors.color2
                            : AppColors.color7,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJobTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тип розміщення',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _jobType = 'offering');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _jobType == 'offering'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Пропоную',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _jobType == 'offering'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _jobType = 'seeking');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _jobType == 'seeking'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Шукаю',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _jobType == 'seeking'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тип розміщення',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _helpType = 'offering');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _helpType == 'offering'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Пропоную',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _helpType == 'offering'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _helpType = 'seeking');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _helpType == 'seeking'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Шукаю',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _helpType == 'seeking'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGiveawayTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Тип розміщення',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _giveawayType = 'giving');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _giveawayType == 'giving'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Віддам',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _giveawayType == 'giving'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _giveawayType = 'taking');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _giveawayType == 'taking'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Прийму',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _giveawayType == 'taking'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConditionTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Стан',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _conditionType = 'new');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _conditionType == 'new'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Новий',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _conditionType == 'new'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _conditionType = 'used');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _conditionType == 'used'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Б/У',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _conditionType == 'used'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSizeSelection() {
    // Implement size selection UI
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Розмір',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(16, 24, 40, 0.05),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _extraFieldValues['size'],
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            hint: Text(
              'Оберіть розмір',
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color5,
              ),
            ),
            items: ['S', 'M', 'L', 'XL'].map<DropdownMenuItem<String>>((
              String value,
            ) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _extraFieldValues['size'] = newValue;
              });
              _validateForm(); // NEW: Validate form after size change
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRadiusRInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Радіус R',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          // Removed padding here, as it's now part of InputDecoration
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: TextField(
            controller: _radiusRController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Введіть радіус',
              hintStyle: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color5,
              ),
              border: InputBorder.none,
              // Adjusted content padding to match other inputs
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            style: AppTextStyles.body1Regular.copyWith(color: AppColors.color2),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Стать',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(color: AppColors.zinc200, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _genderType = 'boy');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _genderType == 'boy'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Хлопчик',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _genderType == 'boy'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _genderType = 'girl');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _genderType == 'girl'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Дівчинка',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _genderType == 'girl'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _genderType = 'both');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _genderType == 'both'
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(200),
                    ),
                    child: Text(
                      'Обидва',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2Medium.copyWith(
                        color: _genderType == 'both'
                            ? Colors.white
                            : AppColors.color2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.gapWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ),
    );

    final Path dashedPath = Path();
    final double dashLength = dashWidth;
    final double gapLength = gapWidth;
    final double totalLength = dashLength + gapLength;

    final double pathLength = _getPathLength(path);
    double currentLength = 0;

    while (currentLength < pathLength) {
      final double start = currentLength;
      final double end = (currentLength + dashLength).clamp(0.0, pathLength);

      if (start < end) {
        final double startT = start / pathLength;
        final double endT = end / pathLength;

        final Offset startPoint = _getPointAt(path, startT);
        final Offset endPoint = _getPointAt(path, endT);

        dashedPath.moveTo(startPoint.dx, startPoint.dy);
        dashedPath.lineTo(endPoint.dx, endPoint.dy);
      }

      currentLength += totalLength;
    }

    canvas.drawPath(dashedPath, paint);
  }

  double _getPathLength(Path path) {
    // Приблизний розрахунок довжини шляху
    return 2 * (100 + 50); // Приблизна довжина для прямокутника
  }

  Offset _getPointAt(Path path, double t) {
    // Приблизний розрахунок точки на шляху
    return Offset(t * 100, t * 50);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
