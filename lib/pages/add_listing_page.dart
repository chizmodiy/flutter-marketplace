import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/category.dart';
import '../services/category_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subcategory.dart';
import '../services/subcategory_service.dart';
import '../models/region.dart';
import 'package:collection/collection.dart'; // Import this for firstWhereOrNull
import '../services/region_service.dart';
import '../models/city.dart'; // Add this import
import '../services/city_service.dart'; // Add this import
import '../services/listing_service.dart';
import 'package:flutter/services.dart';
import '../utils/price_formatter.dart';
import 'dart:math' as math;
import 'dart:async'; // Add this import for Timer

import '../widgets/location_creation_block.dart';
import '../widgets/keyboard_dismisser.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../services/car_service.dart'; // Import car service

import 'package:geolocator/geolocator.dart';

class AddListingPage extends StatefulWidget {
  const AddListingPage({super.key});

  @override
  State<AddListingPage> createState() => _AddListingPageState();
}

class _AddListingPageState extends State<AddListingPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _areaController =
      TextEditingController(); // Controller for square meters
  String? _selectedSize; // Selected size for clothing and shoes
  final TextEditingController _ageController =
      TextEditingController(); // Controller for age
  String? _selectedCarBrand; // Selected car brand (legacy, will be replaced)
  final TextEditingController _yearController =
      TextEditingController(); // Year (legacy)
  final TextEditingController _mileageController =
      TextEditingController(); // Mileage (thousand km)
  final GlobalKey _carBrandKey =
      GlobalKey(); // Key for car brand selector positioning

  // New car selection fields
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
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final PageController _imagePageController = PageController();

  final GlobalKey _categoryButtonKey = GlobalKey();
  final GlobalKey _subcategoryButtonKey = GlobalKey();
  final GlobalKey _regionButtonKey = GlobalKey();

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
  String _selectedMessenger = 'phone';
  final Map<String, TextEditingController> _extraFieldControllers = {};
  final Map<String, dynamic> _extraFieldValues = {};
  bool _isLoading = false;

  // Nominatim City Search
  final TextEditingController _citySearchController = TextEditingController();
  List<City> _cities = []; // NEW: Re-add _cities
  bool _isSearchingCities = false; // NEW: Re-add _isSearchingCities
  City? _selectedCity;
  Timer? _debounceTimer;
  bool _isSettingAddressFromMap = false; // Флаг для встановлення адреси з карти
  String? _selectedAddress;
  String? _selectedRegionName;
  double? _selectedLatitude;
  double? _selectedLongitude;
  final ProfileService _profileService = ProfileService();

  bool _isFormValid = false; // Add form validity state
  bool _submitted = false; // Track if form has been submitted once - RE-ADDED

  // Inline dropdown visibility flags
  bool _isCategoryOpen = false; // NEW: Re-add _isCategoryOpen
  bool _isSubcategoryOpen = false; // NEW: Re-add _isSubcategoryOpen
  bool _isRegionOpen = false; // NEW: Re-add _isRegionOpen

  // Add after: _selectedSubcategory, _selectedCategory, etc.
  String _realEstateType = 'sale'; // 'sale' або 'rent', дефолт — продаж
  String _jobType = 'offering'; // Default to "Пропоную"
  String _helpType = 'offering'; // Default to "Пропоную" for Help category
  String _giveawayType = 'giving'; // Default to "Віддам" for Give away category
  String _conditionType =
      'new'; // Default to "Новий" for Clothing and accessories
  TextEditingController _radiusRController = TextEditingController();
  String _genderType =
      'both'; // Default to "Обидва" for Children's World category

  String? _priceError;

  @override
  void initState() {
    super.initState();
    print('AddListingPage: initState called'); // NEW: Log initState call
    _loadCategories();
    _loadRegions();
    _loadUserPhone(); // Keep this as it was removed accidentally
    // Default contact method: phone, clear others and autofill
    setState(() {
      _selectedMessenger = 'phone';
      _whatsappController.clear();
      _telegramController.clear();
      _viberController.clear();
    });
    _autoFillUserPhone('phone');
    _addFormListeners();
    _validateForm(); // NEW: Initial form validation

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

  void _addFormListeners() {
    _titleController.addListener(_validateForm);
    _descriptionController.addListener(_validateForm);
    _priceController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _whatsappController.addListener(_validateForm);
    _telegramController.addListener(_validateForm);
    _viberController.addListener(_validateForm);

    // NEW: Also listen to changes in selected items
    // This will be handled by calling _validateForm in setState of relevant pickers/toggles
  }

  Future<void> _loadUserPhone() async {
    final userPhone = await _profileService.getUserPhone();
    if (userPhone != null) {
      setState(() {
        // Видаляємо як +380, так і просто 380 з початку номера
        String phoneNumber = userPhone;
        if (phoneNumber.startsWith('+380')) {
          phoneNumber = phoneNumber.substring(4);
        } else if (phoneNumber.startsWith('380')) {
          phoneNumber = phoneNumber.substring(3);
        }
        _phoneController.text = phoneNumber;
      });
    }
  }

  void _autoFillUserPhone(String messengerType) {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && currentUser.phone != null) {
        String phoneNumber = currentUser.phone!;
        // Видаляємо як +380, так і просто 380 з початку номера
        if (phoneNumber.startsWith('+380')) {
          phoneNumber = phoneNumber.substring(4);
        } else if (phoneNumber.startsWith('380')) {
          phoneNumber = phoneNumber.substring(3);
        }

        setState(() {
          switch (messengerType) {
            case 'phone':
              _phoneController.text = phoneNumber;
              break;
            case 'whatsapp':
              _whatsappController.text = phoneNumber;
              break;
            case 'viber':
              _viberController.text = phoneNumber;
              break;
            case 'telegram':
              _telegramController.text = phoneNumber;
              break;
          }
        });
      }
    } catch (e) {
      // Якщо не вдалося завантажити номер, залишаємо поля порожніми
    }
  }

  void _showBlockedUserBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // Неможливо закрити
      enableDrag: false, // Неможливо перетягувати
      builder: (context) => const BlockedUserBottomSheet(),
    );
  }

  Future<void> _loadCategories() async {
    try {
      // Initialize services
      final categoryService = CategoryService();
      final categories = await categoryService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    setState(() {
      _isLoadingSubcategories = true;
      _selectedSubcategory = null;
    });

    try {
      final subcategoryService = SubcategoryService(Supabase.instance.client);
      final subcategories = await subcategoryService
          .getSubcategoriesForCategory(categoryId);
      setState(() {
        _subcategories = subcategories;
        _isLoadingSubcategories = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingSubcategories = false;
      });
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

      // Initialize regions if needed
      await regionService.initializeRegions();

      final regions = await regionService.getRegions();

      // Сортуємо області в алфавітному порядку з урахуванням українського алфавіту
      final sortedRegions = List<Region>.from(regions)
        ..sort((a, b) => _compareUkrainianStrings(a.name, b.name));

      setState(() {
        _regions = sortedRegions;
        _isLoadingRegions = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingRegions = false;
      });
    }
  }

  // Load makes when category "Авто" and subcategory "Легкові автомобілі" is selected
  Future<void> _loadMakes() async {
    if (_selectedCategory?.name != 'Авто' ||
        (_selectedSubcategory?.name != 'Легкові автомобілі' &&
            _selectedSubcategory?.name != 'Автомобілі з Польщі')) {
      return;
    }

    setState(() {
      _isLoadingMakes = true;
    });

    try {
      final makes = await _carService.getMakes();
      setState(() {
        _makes = makes;
        _isLoadingMakes = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingMakes = false;
      });
    }
  }

  // Load models when make is selected
  Future<void> _loadModels(String makeId) async {
    setState(() {
      _isLoadingModels = true;
      _selectedModel = null;
      _selectedStyle = null;
      _selectedModelYear = null;
      _models.clear();
      _styles.clear();
      _modelYears.clear();
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
  Future<void> _loadStyles(String modelId) async {
    setState(() {
      _isLoadingStyles = true;
      _selectedStyle = null;
      _selectedModelYear = null;
      _styles.clear();
      _modelYears.clear();
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
  Future<void> _loadModelYears(String styleId) async {
    setState(() {
      _isLoadingModelYears = true;
      _selectedModelYear = null;
      _modelYears.clear();
    });

    try {
      final modelYears = await _carService.getModelYears(styleId);
      setState(() {
        _modelYears = modelYears;
        _isLoadingModelYears = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingModelYears = false;
      });
    }
  }

  Future<void> _pickImage() async {
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

  Widget _buildImageWidget(String imagePath) {
    if (kIsWeb) {
      return Image.network(
        imagePath,
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
      File(imagePath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.zinc200,
          child: Icon(Icons.error, color: AppColors.color5),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imagePageController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _viberController.dispose();
    _mileageController.dispose();
    _extraFieldControllers.forEach((_, controller) => controller.dispose());
    _citySearchController.dispose();
    _makeSearchController.dispose();
    _modelSearchController.dispose();
    _styleSearchController.dispose();
    _debounceTimer?.cancel();
    _radiusRController.dispose();
    super.dispose();
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
            setState(() {
              _isCategoryOpen = !_isCategoryOpen;
              _isSubcategoryOpen = false;
              _isRegionOpen = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(
                color: _submitted && _selectedCategory == null
                    ? Colors.red
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
        if (_isCategoryOpen)
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
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _buildCategoryItem(category);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryItem(Category category) {
    final isSelected = _selectedCategory?.id == category.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () => _onCategorySelected(category),
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
                  category.name,
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

  void _onCategorySelected(Category category) {
    setState(() {
      _selectedCategory = category;
      _selectedSubcategory = null;
      _realEstateType = 'sale';
      _areaController.clear(); // Clear area field when category changes
      _selectedSize = null; // Clear selected size when category changes
      _ageController.clear(); // Clear age field when category changes
      _selectedCarBrand =
          null; // Clear selected car brand when category changes
      _yearController.clear(); // Clear year field when category changes
      _mileageController.clear(); // Clear mileage field when category changes
      // Clear new car selection fields
      _selectedMake = null;
      _selectedModel = null;
      _selectedStyle = null;
      _selectedModelYear = null;
      _models.clear();
      _styles.clear();
      _modelYears.clear();
    });
    _loadSubcategories(category.id).then((_) {
      // Check if the selected category is 'Віддам безкоштовно'
      if (category.name == 'Віддам безкоштовно') {
        setState(() {
          _isForSale = false; // Set to free
          _priceController.clear(); // Clear price
          _selectedCurrency = 'UAH'; // Reset currency
          _isNegotiablePrice = false; // Reset negotiable
          // Find and set 'Безкоштовно' subcategory if it exists
          final freeSubcategory = _subcategories.firstWhereOrNull(
            (sub) => sub.name == 'Безкоштовно',
          );
          if (freeSubcategory != null) {
            _selectedSubcategory = freeSubcategory;
          }
        });
      } else if (category.name == 'Знайомства') {
        // Handle Dating category
        setState(() {
          _isForSale = false; // Dating listings are considered free
          _priceController.clear();
          _selectedCurrency = 'UAH';
          _isNegotiablePrice = false;
          _ageController
              .clear(); // Clear age controller, will be replaced by range controllers
        });
      } else if (category.name == 'Робота') {
        setState(() {
          _isForSale = false; // "Робота" не продається
          _priceController.clear();
        });
      } else if (category.name == 'Допомога') {
        setState(() {
          _isForSale = false; // "Допомога" не продається
          _priceController.clear();
        });
      } else {
        setState(() {
          _isForSale = true; // Default to for sale
        });
      }
    });
    setState(() {
      _isCategoryOpen = false;
      _isSubcategoryOpen = false;
    });
  }

  Widget _buildSubcategorySection() {
    if (_selectedCategory == null ||
        _selectedCategory!.name ==
            'Віддам безкоштовно' || // Hide if category is 'Віддам безкоштовно'
        _subcategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Підкатегорія',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _subcategoryButtonKey,
          onTap: () {
            setState(() {
              _isSubcategoryOpen = !_isSubcategoryOpen;
              _isCategoryOpen = false;
              _isRegionOpen = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(
                color: _submitted && _selectedSubcategory == null
                    ? Colors.red
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
        if (_isSubcategoryOpen)
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
              itemCount: _subcategories.length,
              itemBuilder: (context, index) {
                final subcategory = _subcategories[index];
                return _buildSubcategoryItem(subcategory);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSubcategoryItem(Subcategory subcategory) {
    final isSelected = _selectedSubcategory?.id == subcategory.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () => _onSubcategorySelected(subcategory),
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
                  subcategory.name,
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

  void _onSubcategorySelected(Subcategory subcategory) {
    setState(() {
      _selectedSubcategory = subcategory;
      // Clear previous extra field controllers
      _extraFieldControllers.forEach((_, controller) => controller.dispose());
      _extraFieldControllers.clear();
      _extraFieldValues.clear();

      // Clear area field when subcategory changes
      _areaController.clear();
      _selectedSize = null; // Clear selected size when subcategory changes
      _ageController.clear(); // Clear age field when subcategory changes
      _selectedCarBrand =
          null; // Clear selected car brand when subcategory changes
      _yearController.clear(); // Clear year field when subcategory changes
      _mileageController
          .clear(); // Clear mileage field when subcategory changes
      // Clear new car selection fields
      _selectedMake = null;
      _selectedModel = null;
      _selectedStyle = null;
      _selectedModelYear = null;
      _models.clear();
      _styles.clear();
      _modelYears.clear();

      // Initialize controllers for new extra fields
      for (var field in subcategory.extraFields) {
        if (field.type == 'number') {
          _extraFieldControllers[field.name] = TextEditingController();
        } else if (field.type == 'range') {
          _extraFieldControllers['${field.name}_min'] = TextEditingController();
          _extraFieldControllers['${field.name}_max'] = TextEditingController();
        }
        // Special handling for age_range as it's a range field, ensure it's captured here.
        if (field.name == 'age_range') {
          _extraFieldControllers['age_range_min'] = TextEditingController();
          _extraFieldControllers['age_range_max'] = TextEditingController();
        }
      }
      _isSubcategoryOpen = false;
    });

    // Load makes if this is car subcategory
    if (subcategory.name == 'Легкові автомобілі' ||
        subcategory.name == 'Автомобілі з Польщі') {
      _loadMakes();
    }

    _validateForm(); // NEW: Validate form after subcategory change
  }

  Widget _buildExtraFieldsSection() {
    if (_selectedSubcategory == null ||
        _selectedSubcategory!.extraFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        ..._selectedSubcategory!.extraFields
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
            .map((field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getFieldDisplayName(field.name),
                    style: AppTextStyles.body2Medium.copyWith(
                      color: AppColors.color8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (field.type == 'number')
                    Container(
                      height: 44, // Фіксована висота 44 пікселі
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
                        controller: _extraFieldControllers[field.name],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: 'Введіть значення',
                          hintStyle: AppTextStyles.body1Regular.copyWith(
                            color: AppColors.color5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          suffixText: field.unit,
                          suffixStyle: AppTextStyles.body1Regular.copyWith(
                            color: AppColors.color8,
                          ),
                        ),
                        style: AppTextStyles.body1Regular.copyWith(
                          color: AppColors.color2,
                        ),
                        onChanged: (value) {
                          _extraFieldValues[field.name] = int.tryParse(value);
                        },
                      ),
                    )
                  else if (field.type == 'select')
                    GestureDetector(
                      onTap: () => _showOptionsDialog(field),
                      child: Container(
                        height: 44, // Фіксована висота 44 пікселі
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _extraFieldValues[field.name] ??
                                    'Оберіть значення',
                                style: AppTextStyles.body1Regular.copyWith(
                                  color: _extraFieldValues[field.name] != null
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
                    )
                  else if (field.type == 'range')
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44, // Фіксована висота 44 пікселі
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
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
                                  controller:
                                      _extraFieldControllers['${field.name}_min'],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    hintText: 'від',
                                    hintStyle: AppTextStyles.body1Regular
                                        .copyWith(color: AppColors.color5),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    suffixText: field.unit,
                                    suffixStyle: AppTextStyles.body1Regular
                                        .copyWith(color: AppColors.color8),
                                  ),
                                  style: AppTextStyles.body1Regular.copyWith(
                                    color: AppColors.color2,
                                  ),
                                  onChanged: (value) {
                                    final minValue = int.tryParse(value);
                                    final maxValue = int.tryParse(
                                      _extraFieldControllers['${field.name}_max']
                                              ?.text ??
                                          '',
                                    );
                                    if (minValue != null) {
                                      _extraFieldValues[field.name] = {
                                        'min': minValue,
                                        'max': maxValue,
                                      };
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '-',
                              style: AppTextStyles.body1Regular.copyWith(
                                color: AppColors.color8,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 44, // Фіксована висота 44 пікселі
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
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
                                  controller:
                                      _extraFieldControllers['${field.name}_max'],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    hintText: 'до',
                                    hintStyle: AppTextStyles.body1Regular
                                        .copyWith(color: AppColors.color5),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    suffixText: field.unit,
                                    suffixStyle: AppTextStyles.body1Regular
                                        .copyWith(color: AppColors.color8),
                                  ),
                                  style: AppTextStyles.body1Regular.copyWith(
                                    color: AppColors.color2,
                                  ),
                                  onChanged: (value) {
                                    final maxValue = int.tryParse(value);
                                    final minValue = int.tryParse(
                                      _extraFieldControllers['${field.name}_min']
                                              ?.text ??
                                          '',
                                    );
                                    if (maxValue != null) {
                                      _extraFieldValues[field.name] = {
                                        'min': minValue,
                                        'max': maxValue,
                                      };
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                ],
              );
            }),
      ],
    );
  }

  void _showOptionsDialog(ExtraField field) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width - 26,
            constraints: const BoxConstraints(maxHeight: 320),
            margin: const EdgeInsets.symmetric(horizontal: 13),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...?field.options?.map(
                    (option) => _buildOptionItem(field.name, option),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem(String fieldName, String option) {
    final isSelected = _extraFieldValues[fieldName] == option;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _extraFieldValues[fieldName] = option;
          });
          Navigator.pop(context);
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
                  option,
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

  String _getFieldDisplayName(String fieldName) {
    // Convert field names to display names
    switch (fieldName) {
      // Авто
      case 'year':
        return 'Рік випуску';
      case 'brand':
        return 'Марка';
      case 'car_brand':
        return 'Марка авто';
      case 'engine_hp':
        return 'Потужність двигуна';
      case 'engine_power_hp':
        return 'Двигун (к.с.)';
      case 'mileage':
        return 'Пробіг (км)';
      case 'fuel_type':
        return 'Тип палива';
      case 'transmission':
        return 'Коробка передач';
      case 'body_type':
        return 'Тип кузова';
      case 'color':
        return 'Колір';

      // Нерухомість
      case 'area':
        return 'Площа (м²)';
      case 'square_meters':
        return 'Площа (м²)';
      case 'rooms':
        return 'Кількість кімнат';
      case 'floor':
        return 'Поверх';
      case 'total_floors':
        return 'Всього поверхів';
      case 'property_type':
        return 'Тип нерухомості';
      case 'renovation':
        return 'Ремонт';
      case 'furniture':
        return 'Меблі';
      case 'balcony':
        return 'Балкон';
      case 'parking':
        return 'Парковка';

      // Електроніка
      case 'model':
        return 'Модель';
      case 'memory':
        return 'Пам\'ять';
      case 'storage':
        return 'Накопичувач';
      case 'processor':
        return 'Процесор';
      case 'screen_size':
        return 'Розмір екрану';
      case 'battery':
        return 'Батарея';

      // Одяг
      case 'size':
        return 'Розмір';
      case 'material':
        return 'Матеріал';
      case 'season':
        return 'Сезон';
      case 'style':
        return 'Стиль';
      case 'gender':
        return 'Стать';

      // Загальні
      case 'condition':
        return 'Стан';
      case 'warranty':
        return 'Гарантія';
      case 'delivery':
        return 'Доставка';
      case 'payment':
        return 'Оплата';

      default:
        // Convert snake_case to Title Case
        return fieldName
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  Widget _buildRegionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Область',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _regionButtonKey,
          onTap: () {
            setState(() {
              _isRegionOpen = !_isRegionOpen;
              _isCategoryOpen = false;
              _isSubcategoryOpen = false;
            });
          },
          child: Container(
            height: 44, // Фіксована висота 44 пікселі
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(
                color: _submitted && _selectedRegion == null
                    ? Colors.red
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
              children: [
                Expanded(
                  child: Text(
                    _selectedRegion?.name ?? 'Оберіть область',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: _selectedRegion != null
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
        if (_isRegionOpen)
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
              itemCount: _regions.length,
              itemBuilder: (context, index) {
                final region = _regions[index];
                return _buildRegionItem(region);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRegionItem(Region region) {
    final isSelected = _selectedRegion?.id == region.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        onTap: () => _onRegionSelected(region),
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
                  region.name,
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

  void _onRegionSelected(Region region) {
    setState(() {
      _selectedRegion = region;
      _selectedRegionName = region.name; // Встановлюємо назву області
      _selectedCity = null; // Clear selected city when region changes
      _cities.clear(); // Clear city search results
      _citySearchController.clear(); // Clear city search input
      _isRegionOpen = false;
    });
    // Automatically search for cities in the selected region or prompt user
    // _onCitySearchChanged('', regionName: region.name); // You can uncomment this to auto-load cities
  }

  Future<void> _onCitySearchChanged(String query, {String? regionName}) async {
    print(
      'DEBUG (AddListingPage): _onCitySearchChanged called with query: "$query"',
    );
    print(
      'DEBUG (AddListingPage): Current _citySearchController.text: "${_citySearchController.text}"',
    );

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      print(
        'DEBUG (AddListingPage): _onCitySearchChanged debounce timer fired, query: "$query"',
      );
      setState(() {
        _isSearchingCities = true;
        _cities.clear();
      });

      try {
        final cityService = CityService();
        final String effectiveRegionName =
            regionName ?? _selectedRegion?.name ?? '';

        // Pass bounding box coordinates if available
        final results = await cityService.searchCities(
          query,
          regionName: effectiveRegionName,
          minLat: _selectedRegion?.minLat,
          maxLat: _selectedRegion?.maxLat,
          minLon: _selectedRegion?.minLon,
          maxLon: _selectedRegion?.maxLon,
        );

        setState(() {
          _cities = results;
        });
      } catch (e) {
        setState(() {
          _cities = [];
        });
      } finally {
        setState(() {
          _isSearchingCities = false;
        });
      }
    });
  }

  Widget _buildCitySection() {
    if (_selectedRegion == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Показуємо обрану область
        if (_selectedRegion != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.zinc50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.zinc200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Область: ${_selectedRegion!.name}',
                  style: AppTextStyles.body2Medium.copyWith(
                    color: AppColors.color2,
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Місто',
          style: AppTextStyles.body2Medium.copyWith(color: AppColors.color8),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44, // Фіксована висота 44 пікселі
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.zinc50,
            borderRadius: BorderRadius.circular(200),
            border: Border.all(
              color: _submitted && _selectedCity == null
                  ? Colors.red
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Логуємо, що саме відображається в TextField
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      print(
                        'DEBUG (AddListingPage): TextField builder - _citySearchController.text: "${_citySearchController.text}"',
                      );
                      print(
                        'DEBUG (AddListingPage): TextField builder - _selectedCity?.name: "${_selectedCity?.name}"',
                      );
                    });

                    return TextField(
                      controller: _citySearchController,
                      textAlignVertical: TextAlignVertical.center,
                      style: AppTextStyles.body1Regular.copyWith(
                        color: _selectedCity != null
                            ? AppColors.color2
                            : AppColors.color5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Оберіть місто',
                        hintStyle: AppTextStyles.body1Regular.copyWith(
                          color: AppColors.color5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: _isSearchingCities
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      onTap: () {
                        if (_cities.isEmpty && !_isSearchingCities) {
                          _onCitySearchChanged(
                            '',
                            regionName: _selectedRegion!.name,
                          );
                        }
                      },
                      onChanged: (value) {
                        print(
                          'DEBUG (AddListingPage): TextField onChanged called with value: "$value"',
                        );
                        print(
                          'DEBUG (AddListingPage): _isSettingAddressFromMap: $_isSettingAddressFromMap',
                        );

                        // Не викликаємо пошук, якщо встановлюємо адресу з карти
                        if (_isSettingAddressFromMap) {
                          print(
                            'DEBUG (AddListingPage): Skipping _onCitySearchChanged because _isSettingAddressFromMap is true',
                          );
                          return;
                        }

                        if (value.isEmpty) {
                          setState(() {
                            _selectedCity = null;
                          });
                        }
                        _onCitySearchChanged(
                          value,
                          regionName: _selectedRegion!.name,
                        );
                      },
                    );
                  },
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
        // Випадаючий список
        if (_cities.isNotEmpty || _isSearchingCities)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(200),
                bottomRight: Radius.circular(200),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(16, 24, 40, 0.03),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: _isSearchingCities
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _cities.length,
                    itemBuilder: (context, index) {
                      final city = _cities[index];
                      return _buildCityItem(city);
                    },
                  ),
          ),
      ],
    );
  }

  Widget _buildCityItem(City city) {
    final isSelected = _selectedCity?.id == city.id;
    return InkWell(
      onTap: () => _onCitySelected(city),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.zinc50 : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                city.name,
                style: AppTextStyles.body1Regular.copyWith(
                  color: AppColors.color2,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
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
    );
  }

  void _onCitySelected(City city) {
    setState(() {
      _selectedCity = city;
      _citySearchController.text = city.name;
      _cities.clear(); // Закриваємо випадаючий список
    });
    _validateForm(); // NEW: Validate form after city selection
  }

  Widget _buildListingTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.zinc100,
        borderRadius: BorderRadius.circular(200),
        border: Border.all(color: AppColors.zinc50, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isForSale = true;
                  // Clear price and currency when switching to paid
                  _priceController.clear();
                  _selectedCurrency = 'UAH';
                  _isNegotiablePrice = false;
                });
                _validateForm(); // NEW: Validate form after toggle
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isForSale ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(200),
                  border: Border.all(
                    color: _isForSale ? AppColors.zinc200 : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: _isForSale
                      ? const [
                          BoxShadow(
                            color: Color.fromRGBO(16, 24, 40, 0.05),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Продати',
                    style: AppTextStyles.body2Semibold.copyWith(
                      color: _isForSale ? AppColors.color2 : AppColors.color7,
                    ),
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
                  // Don't clear subcategory and extra fields when switching to free
                  // Keep the selected subcategory and extra fields
                });
                _validateForm(); // NEW: Validate form after toggle
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: !_isForSale ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(200),
                  border: Border.all(
                    color: !_isForSale ? AppColors.zinc200 : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: !_isForSale
                      ? const [
                          BoxShadow(
                            color: Color.fromRGBO(16, 24, 40, 0.05),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Безкоштовно',
                    style: AppTextStyles.body2Semibold.copyWith(
                      color: !_isForSale ? AppColors.color2 : AppColors.color7,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySection() {
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
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(200),
              borderSide: BorderSide(
                color: AppColors.notificationDotColor,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(200),
              borderSide: BorderSide(
                color: AppColors.notificationDotColor,
                width: 1,
              ),
            ),
            errorText: _priceError,
            errorStyle: AppTextStyles.body2Regular.copyWith(
              color: AppColors.notificationDotColor,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _validatePrice(value);
            });
          },
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

        // Автоматично заповнюємо номер телефону користувача при зміні месенджера
        _autoFillUserPhone(type);
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
    // Визначаємо, чи потрібно показувати помилку для цього поля
    bool shouldShowError = false;
    if (_submitted) {
      if (controller == _phoneController &&
          _selectedMessenger == 'phone' &&
          controller.text.isEmpty) {
        shouldShowError = true;
      } else if (controller == _whatsappController &&
          _selectedMessenger == 'whatsapp' &&
          controller.text.isEmpty) {
        shouldShowError = true;
      } else if (controller == _telegramController &&
          _selectedMessenger == 'telegram' &&
          controller.text.isEmpty) {
        shouldShowError = true;
      } else if (controller == _viberController &&
          _selectedMessenger == 'viber' &&
          controller.text.isEmpty) {
        shouldShowError = true;
      }
    }

    return Container(
      height: 44, // Фіксована висота 44 пікселі
      decoration: BoxDecoration(
        color: AppColors.zinc50,
        borderRadius: BorderRadius.circular(200),
        border: Border.all(
          color: shouldShowError ? Colors.red : AppColors.zinc200,
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
        children: [
          if (!isTelegramInput) ...[
            const SizedBox(width: 16),
            // Прапор України
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0057B8), // Синій колір прапора
              ),
              child: ClipOval(
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0057B8), // Синій колір
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD700), // Жовтий колір
                      ),
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
                inputFormatters: isTelegramInput
                    ? []
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        _PhoneNumberFormatter(),
                      ],
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

  Widget _buildContactForm() {
    final bool hasAnyContactFieldEmpty =
        _phoneController.text.isEmpty &&
        _whatsappController.text.isEmpty &&
        _telegramController.text.isEmpty &&
        _viberController.text.isEmpty;

    final String? phoneError =
        _submitted &&
            _selectedMessenger == 'phone' &&
            _phoneController.text.isEmpty
        ? 'Введіть номер телефону'
        : null;
    final String? whatsappError =
        _submitted &&
            _selectedMessenger == 'whatsapp' &&
            _whatsappController.text.isEmpty
        ? 'Введіть номер WhatsApp'
        : null;
    final String? telegramError =
        _submitted &&
            _selectedMessenger == 'telegram' &&
            _telegramController.text.isEmpty
        ? 'Введіть номер Telegram'
        : null;
    final String? viberError =
        _submitted &&
            _selectedMessenger == 'viber' &&
            _viberController.text.isEmpty
        ? 'Введіть номер Viber'
        : null;

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
        if (_selectedMessenger == 'phone') ...[
          _buildPhoneInput(
            controller: _phoneController,
            hintText: '(XX) XXX-XX-XX',
          ),
        ] else if (_selectedMessenger == 'whatsapp') ...[
          _buildPhoneInput(
            controller: _whatsappController,
            hintText: 'https://chat.whatsapp.com/username',
          ),
        ] else if (_selectedMessenger == 'telegram') ...[
          _buildPhoneInput(
            controller: _telegramController,
            hintText: '(XX) XXX-XX-XX',
          ),
        ] else if (_selectedMessenger == 'viber') ...[
          _buildPhoneInput(
            controller: _viberController,
            hintText: 'https://invite.viber.com/?g2=xxxxxx',
          ),
        ],
      ],
    );
  }

  String? _validateExtraFields() {
    String? errorMessage; // Make errorMessage nullable

    for (var field in _selectedSubcategory!.extraFields) {
      if (field.isRequired &&
          (!_extraFieldValues.containsKey(field.id) ||
              _extraFieldValues[field.id] == null ||
              (_extraFieldValues[field.id] is String &&
                  _extraFieldValues[field.id].isEmpty))) {
        errorMessage = 'Будь ласка, заповніть всі обов\'язкові поля.';

        break;
      }
    }

    if (errorMessage == null) {}
    return errorMessage; // Return nullable errorMessage
  }

  void _validateForm() {
    // Changed return type to void
    print('AddListingPage: _validateForm called (temporary override)');

    // Making Title and Description optional: always valid
    final isTitleValid = true; // _titleController.text.isNotEmpty;
    final isDescriptionValid = true; // _descriptionController.text.isNotEmpty;
    final isCategorySelected = _selectedCategory != null;
    final isSubcategorySelected =
        _selectedCategory?.name == 'Віддам безкоштовно' ||
        _selectedSubcategory != null;
    final areContactInfoValid = _isContactInfoValid();
    final isPriceSectionValid = _isPriceValid();
    final areImagesSelected = _selectedImages.isNotEmpty;

    print(
      '-------------------- Form Validation Log (AddListingPage) --------------------',
    );
    print('Title Valid: $isTitleValid (Optional)');
    print('Description Valid: $isDescriptionValid (Optional)');
    print('Category Selected: $isCategorySelected');
    print('Subcategory Selected: $isSubcategorySelected');
    print('Contact Info Valid: $areContactInfoValid');
    print(
      'Price Section Valid: $isPriceSectionValid (Is For Sale: $_isForSale, Price: ${_priceController.text})',
    );
    print('Images Selected: $areImagesSelected');

    // NEW: Include extra fields validation
    final areExtraFieldsValid =
        _validateExtraFieldsInternal(); // Internal helper for extra fields
    print('Extra Fields Valid: $areExtraFieldsValid');

    final overallFormValid =
        isTitleValid &&
        isDescriptionValid &&
        isCategorySelected &&
        isSubcategorySelected &&
        areContactInfoValid &&
        isPriceSectionValid &&
        areImagesSelected &&
        areExtraFieldsValid; // Include extra fields in overall validation

    print('Overall Form Valid before setState: $overallFormValid');
    print('Current _isFormValid before setState: $_isFormValid');

    if (_isFormValid != overallFormValid) {
      setState(() {
        _isFormValid = overallFormValid;
        print('AddListingPage: _isFormValid changed to: $_isFormValid');
      });
    }

    // Optionally show snackbar for contact info if not valid, but only after first submission attempt
    if (_submitted && !areContactInfoValid) {
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

  // NEW: Helper for price validity
  bool _isPriceValid() {
    if (!_isForSale) return true; // Price is not relevant for free listings
    final cleanValue = _priceController.text.replaceAll(' ', '');
    final price = double.tryParse(cleanValue);
    return price != null && price >= 0;
  }

  // NEW: Helper for contact info validity (single selected method only)
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

  // NEW: Internal helper for extra fields validation
  bool _validateExtraFieldsInternal() {
    if (_selectedSubcategory == null ||
        _selectedSubcategory!.extraFields.isEmpty) {
      return true; // No extra fields, so they are valid by default
    }

    for (var field in _selectedSubcategory!.extraFields) {
      if (field.isRequired) {
        // Handle different types of extra fields
        if (field.type == 'number') {
          final controller = _extraFieldControllers[field.name];
          if (controller == null ||
              controller.text.isEmpty ||
              double.tryParse(controller.text) == null) {
            return false; // Required number field is empty or invalid
          }
        } else if (field.type == 'range') {
          final minController = _extraFieldControllers['${field.name}_min'];
          final maxController = _extraFieldControllers['${field.name}_max'];
          if (minController == null ||
              minController.text.isEmpty ||
              double.tryParse(minController.text) == null ||
              maxController == null ||
              maxController.text.isEmpty ||
              double.tryParse(maxController.text) == null) {
            return false; // Required range field is empty or invalid
          }
        } else if (field.type == 'select') {
          final selectedValue = _extraFieldValues[field.name];
          if (selectedValue == null ||
              (selectedValue is String && selectedValue.isEmpty)) {
            return false; // Required select field is not selected
          }
        } else {
          // Generic check for other types
          final value = _extraFieldValues[field.name];
          if (value == null || (value is String && value.isEmpty)) {
            return false; // Required generic field is empty
          }
        }
      }
    }
    return true; // All required extra fields are valid
  }

  // Add listeners for extra field controllers
  void _addExtraFieldListeners() {
    _extraFieldControllers.forEach((key, controller) {
      controller.addListener(_validateForm);
    });
  }

  // Метод створення оголошення
  Future<void> _createListing() async {
    // Захист від множинних натискань
    if (_isLoading) {
      print(
        'DEBUG (AddListingPage): _createListing called, but isLoading is true. Returning.',
      );
      return;
    }

    setState(() {
      _submitted =
          true; // Встановлюємо _submitted в true одразу при спробі створення оголошення
      _validateForm(); // Re-validate to ensure _isFormValid is up-to-date
    });
    print('DEBUG (AddListingPage): _submitted set to true.');

    if (!_isFormValid) {
      print('DEBUG (AddListingPage): Form is not valid. Stopping creation.');
      // Show general validation error if needed (e.g., if a required field is empty)
      if (mounted && _formKey.currentState != null) {
        _formKey.currentState!
            .validate(); // Trigger form field validation to show errors
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Будь ласка, заповніть всі обов\'язкові поля'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false; // Reset loading state in case of validation error
      });
      return;
    }

    print('DEBUG (AddListingPage): Form validation passed.');

    setState(() {
      _isLoading = true;
    });

    try {
      final listingService = ListingService(Supabase.instance.client);

      // Convert XFile to File for upload if needed, or handle directly
      final List<XFile> imagesToUpload = _selectedImages;

      // Prepare custom attributes, including range values
      Map<String, dynamic> finalCustomAttributes = Map.from(_extraFieldValues);

      // Process range fields from text controllers
      for (var field in _selectedSubcategory!.extraFields) {
        if (field.type == 'range') {
          final minController = _extraFieldControllers['${field.name}_min'];
          final maxController = _extraFieldControllers['${field.name}_max'];
          final minValue = int.tryParse(minController?.text ?? '');
          final maxValue = int.tryParse(maxController?.text ?? '');

          if (minValue != null || maxValue != null) {
            finalCustomAttributes[field.name] = {
              'min': minValue,
              'max': maxValue,
            };
          }
        }
      }

      // Add area value if it's entered
      if (_areaController.text.isNotEmpty) {
        final areaValue = double.tryParse(_areaController.text);
        if (areaValue != null && areaValue > 0) {
          finalCustomAttributes['area'] = areaValue;
        }
      }

      // Add size value if selected
      if (_selectedSize != null) {
        finalCustomAttributes['size'] = _selectedSize;
      }

      // Add age value if entered
      if (_ageController.text.isNotEmpty) {
        final ageValue = int.tryParse(_ageController.text);
        if (ageValue != null && ageValue > 0) {
          finalCustomAttributes['age'] = ageValue;
        }
      }

      // Add car brand if selected
      if (_selectedCarBrand != null) {
        finalCustomAttributes['car_brand'] = _selectedCarBrand;
      }

      // Add year if entered
      // Для легкових автомобілів рік береться з дропдауна, для інших - з текстового поля
      final isPassengerCar =
          _selectedSubcategory?.name == 'Легкові автомобілі' ||
          _selectedSubcategory?.name == 'Автомобілі з Польщі';

      if (isPassengerCar && _selectedModelYear != null) {
        // Для легкових автомобілів рік зберігається через model_year_id
        // Можна також додати рік в custom_attributes для сумісності
        finalCustomAttributes['year'] = _selectedModelYear!.year;
      } else if (!isPassengerCar && _yearController.text.isNotEmpty) {
        // Для інших підкатегорій авто - з текстового поля
        final year = int.tryParse(_yearController.text);
        if (year != null && year > 0) {
          finalCustomAttributes['year'] = year;
        }
      }

      // Add mileage (thousand km) if entered
      double? mileageThousands;
      if (_mileageController.text.isNotEmpty) {
        mileageThousands = double.tryParse(_mileageController.text);
      }

      String locationString = '';
      if (_selectedRegion != null) {
        locationString = _selectedRegion!.name;
      } else if (_selectedRegionName != null) {
        locationString = _selectedRegionName!;
      }

      // Use selected subcategory (now required for all listings)
      final subcategoryId = _selectedSubcategory!.id;

      print('DEBUG (AddListingPage): Creating listing with location data:');
      print('  address: $_selectedAddress');
      print('  region: $_selectedRegionName');
      print('  latitude: $_selectedLatitude');
      print('  longitude: $_selectedLongitude');
      print('  city: ${_selectedCity?.name}');

      await listingService.createListing(
        title: _titleController.text,
        description: _descriptionController.text,
        categoryId: _selectedCategory!.id,
        subcategoryId: subcategoryId, // Use selected subcategory ID
        location: locationString,
        isFree: !_isForSale,
        currency: _isForSale ? _selectedCurrency : null,
        price: _isForSale
            ? double.tryParse(_priceController.text.replaceAll(' ', ''))
            : null,
        isNegotiable: _isForSale ? _isNegotiablePrice : null,
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
        viber: _selectedMessenger == 'viber' && _viberController.text.isNotEmpty
            ? '+380${_viberController.text}'
            : null,
        customAttributes: _isForSale
            ? finalCustomAttributes
            : {}, // Empty attributes for free listings
        images: imagesToUpload,
        address: _selectedAddress,
        region: _selectedRegionName,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        realEstateType: _selectedCategory?.name == 'Нерухомість'
            ? _realEstateType
            : null,
        mileageThousands: mileageThousands,
        jobType: _selectedCategory?.name == 'Робота' ? _jobType : null,
        helpType: _selectedCategory?.name == 'Допомога' ? _helpType : null,
        giveawayType: _selectedCategory?.name == 'Віддам безкоштовно'
            ? _giveawayType
            : null,
        conditionType: _selectedCategory?.name == 'Одяг та аксесуари'
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
        makeId: _selectedMake?.id,
        modelId: _selectedModel?.id,
        styleId: _selectedStyle?.id,
        modelYearId: _selectedModelYear?.id,
      );

      print('DEBUG (AddListingPage): Listing created successfully.');

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      print('ERROR (AddListingPage): Error creating listing: $error');
      print('STACK (AddListingPage): $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка створення оголошення: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
            onTap: _isLoading
                ? null
                : () {
                    Navigator.of(context).pop();
                  },
            child: Icon(Icons.arrow_back, color: AppColors.color2, size: 24),
          ),
          title: Text(
            'Додати оголошення',
            style: AppTextStyles.heading2Semibold.copyWith(
              color: AppColors.color2,
            ),
          ),
        ),
        body: Listener(
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
            padding: const EdgeInsets.symmetric(
              horizontal: 13.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Divider
                Container(height: 1, color: AppColors.zinc200),
                const SizedBox(height: 20),

                // Add Photo Section
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
                  onTap: _pickImage,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.zinc50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _submitted && _selectedImages.isEmpty
                              ? Colors.red
                              : AppColors.zinc200, // <--- ЗМІНІТЬ ЦЕЙ РЯДОК
                          width: 1.0,
                        ),
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            List.generate(_selectedImages.length, (index) {
                                  final imagePath = _selectedImages[index].path;
                                  return SizedBox(
                                    width: 92,
                                    height: 92,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: _buildImageWidget(imagePath),
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
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(200),
                                                color: const Color.fromARGB(
                                                  0,
                                                  255,
                                                  255,
                                                  255,
                                                ),
                                              ),
                                              child: SvgPicture.asset(
                                                'assets/icons/x-close.svg',
                                                width: 20,
                                                height: 20,
                                                colorFilter: ColorFilter.mode(
                                                  AppColors.color7,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .expand(
                                  (widget) => [
                                    widget,
                                    const SizedBox(width: 6),
                                  ],
                                )
                                .toList(), // Додаємо SizedBox між фото
                      ),
                    ),
                  ),
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
                    controller: _titleController,
                    style: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Введіть текст',
                      hintStyle: AppTextStyles.body1Regular.copyWith(
                        color: AppColors.color5,
                      ),
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
                    controller: _descriptionController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Введіть текст',
                      hintStyle: AppTextStyles.body1Regular.copyWith(
                        color: AppColors.color5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Category Dropdown
                _buildCategorySection(),

                // Subcategory Section
                _buildSubcategorySection(),

                // Spacing before category-specific toggles
                if (_selectedCategory?.name == 'Нерухомість' ||
                    _selectedCategory?.name == 'Робота' ||
                    _selectedCategory?.name == 'Допомога' ||
                    _selectedCategory?.name == 'Віддам безкоштовно' ||
                    _selectedCategory?.name == 'Одяг та аксесуари' ||
                    _selectedCategory?.name == 'Дитячий світ')
                  const SizedBox(height: 20),

                // Real Estate Type Toggle
                if (_selectedCategory?.name == 'Нерухомість' &&
                    _selectedSubcategory != null)
                  _buildRealEstateTypeToggle(),
                // Job Type Toggle
                if (_selectedCategory?.name == 'Робота') _buildJobTypeToggle(),
                // Help Type Toggle
                if (_selectedCategory?.name == 'Допомога')
                  const SizedBox.shrink(),
                // Giveaway Type Toggle
                if (_selectedCategory?.name == 'Віддам безкоштовно')
                  _buildGiveawayTypeToggle(),
                // Condition Type Toggle
                if (_selectedCategory?.name == 'Одяг та аксесуари' ||
                    _selectedCategory?.name == 'Дитячий світ')
                  _buildConditionTypeToggle(),

                const SizedBox(height: 20), // Add spacing here
                // Size Selection
                if (_selectedCategory?.name == 'Одяг та аксесуари')
                  _buildSizeSelection(),

                // Radius R Input
                if (_selectedCategory?.name == 'Запчастини для транспорту' &&
                    _selectedSubcategory?.name == 'Шини, диски і колеса')
                  _buildRadiusRInput(),

                // Gender Type Toggle (for Children's World)
                if (_selectedCategory?.name == 'Дитячий світ')
                  _buildGenderTypeToggle(),

                // Додаткові поля (без зайвого відступу перед ними)
                _buildAreaField(),
                _buildSizeSelector(),
                _buildAgeField(),
                _buildCarBrandSelector(),
                _buildCarFields(),
                // Додаємо LocationPicker після категорії та підкатегорії
                const SizedBox(height: 20),
                // LocationCreationBlock для вибору координат
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LocationCreationBlock(
                    onLocationSelected: (latLng, address, regionName, cityName) async {
                      print(
                        'DEBUG (AddListingPage): onLocationSelected callback called',
                      );
                      print(
                        '  latLng: ${latLng.latitude}, ${latLng.longitude}',
                      );
                      print('  address: $address');
                      print('  regionName: $regionName');
                      print('  cityName: $cityName');

                      if (latLng != null) {
                        // Спочатку шукаємо область за назвою (якщо передана)
                        Region? foundRegion;
                        if (regionName != null) {
                          foundRegion = _regions.firstWhereOrNull(
                            (region) => region.name == regionName,
                          );
                        }

                        // Якщо область не знайдена за назвою, шукаємо за координатами
                        if (foundRegion == null) {
                          double shortestDistance = double.infinity;

                          for (final region in _regions) {
                            if (region.minLat != null &&
                                region.maxLat != null &&
                                region.minLon != null &&
                                region.maxLon != null) {
                              // Обчислюємо центр області
                              final centerLat =
                                  (region.minLat! + region.maxLat!) / 2;
                              final centerLon =
                                  (region.minLon! + region.maxLon!) / 2;

                              final distance = Geolocator.distanceBetween(
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

                        print('DEBUG (AddListingPage): Before setState:');
                        print('  foundRegion: ${foundRegion?.name}');
                        print('  _selectedAddress (before): $_selectedAddress');

                        // Встановлюємо знайдену область та координати
                        // Спочатку встановлюємо текст в поле міста, щоб він не перезаписався
                        final addressToShow = address ?? cityName ?? '';

                        // Встановлюємо флаг, щоб не викликати _onCitySearchChanged
                        _isSettingAddressFromMap = true;

                        _citySearchController.value = TextEditingValue(
                          text: addressToShow,
                          selection: TextSelection.collapsed(
                            offset: addressToShow.length,
                          ),
                        );

                        setState(() {
                          _selectedRegion = foundRegion;
                          _selectedRegionName = foundRegion?.name ?? regionName;
                          // Встановлюємо _selectedCity з повною адресою як назвою, щоб валідація працювала
                          _selectedCity = addressToShow.isNotEmpty
                              ? City(
                                  name: addressToShow,
                                  regionId: regionName ?? '',
                                )
                              : null;
                          _selectedLatitude = latLng.latitude;
                          _selectedLongitude = latLng.longitude;
                          _selectedAddress = address ?? 'Обрана локація';
                        });

                        // Скидаємо флаг після встановлення
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _isSettingAddressFromMap = false;
                          print(
                            'DEBUG (AddListingPage): _isSettingAddressFromMap reset to false',
                          );
                          print(
                            'DEBUG (AddListingPage): _citySearchController.text after delay: "${_citySearchController.text}"',
                          );
                        });

                        // Додаткова перевірка через 200ms
                        Future.delayed(const Duration(milliseconds: 200), () {
                          print(
                            'DEBUG (AddListingPage): _citySearchController.text after 200ms: "${_citySearchController.text}"',
                          );
                          print(
                            'DEBUG (AddListingPage): _selectedCity?.name after 200ms: "${_selectedCity?.name}"',
                          );
                        });

                        print(
                          'DEBUG (AddListingPage): _citySearchController.text set to: ${_citySearchController.text}',
                        );
                        print(
                          'DEBUG (AddListingPage): _isSettingAddressFromMap set to true, will reset after 100ms',
                        );

                        print('DEBUG (AddListingPage): After setState:');
                        print('  _selectedAddress: $_selectedAddress');
                        print('  _selectedCity?.name: ${_selectedCity?.name}');
                        print('  _selectedRegionName: $_selectedRegionName');
                        print(
                          '  _citySearchController.text (before postFrameCallback): ${_citySearchController.text}',
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // City Selection (область вже обирається в LocationPicker)
                _buildCitySection(),
                const SizedBox(height: 20),

                // Listing Type Toggle
                if (_selectedCategory?.name != 'Віддам безкоштовно' &&
                    _selectedCategory?.name != 'Знайомства' &&
                    !(_selectedCategory?.name == 'Нерухомість' &&
                        _selectedSubcategory != null) &&
                    _selectedCategory?.name != 'Робота' &&
                    _selectedCategory?.name != 'Допомога' &&
                    _selectedCategory?.name != 'Одяг та аксесуари' &&
                    _selectedCategory?.name != 'Дитячий світ') ...[
                  _buildListingTypeToggle(),
                  const SizedBox(height: 20),
                ],

                // Currency Section (only show if not free)
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

                // Buttons (scroll with content)
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            print(
                              'DEBUG (AddListingPage): "Підтвердити" button pressed. Form is valid: $_isFormValid. Calling _createListing().',
                            );
                            _createListing();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFormValid
                          ? AppColors.primaryColor
                          : AppColors.primaryColor, // Завжди основний колір
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.zinc200,
                      disabledForegroundColor: AppColors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Підтвердити',
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
                    onPressed: _isLoading
                        ? null
                        : () {
                            // Clear all data
                            setState(() {
                              _titleController.clear();
                              _descriptionController.clear();
                              _priceController.clear();
                              _selectedImages.clear();
                              _selectedCategory = null;
                              _selectedSubcategory = null;
                              _selectedRegion = null;
                              _isForSale = true;
                              _selectedCurrency = 'UAH';
                              _isNegotiablePrice = false;
                              _phoneController.clear();
                              _whatsappController.clear();
                              _telegramController.clear();
                              _viberController.clear();
                              _selectedMessenger = 'phone';
                              _extraFieldControllers.forEach(
                                (_, controller) => controller.dispose(),
                              );
                              _extraFieldControllers.clear();
                              _extraFieldValues.clear();
                              _areaController.clear(); // Clear area field
                              _selectedSize = null; // Clear selected size
                              _ageController.clear(); // Clear age field
                              _selectedCarBrand =
                                  null; // Clear selected car brand
                              _yearController.clear(); // Clear year field
                              _mileageController.clear(); // Clear mileage field
                              _radiusRController
                                  .clear(); // Clear radius R field
                              _genderType = 'both'; // Reset gender type
                            });

                            // Navigate to main page
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/', (route) => false);
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getCarBrands() {
    return [
      'Volkswagen',
      'BMW',
      'Audi',
      'Mercedes-Benz',
      'Toyota',
      'Renault',
      'Skoda',
      'Ford',
      'Nissan',
      'Opel',
      'Інше',
    ];
  }

  List<String> _getSizesForSubcategory() {
    print(
      'DEBUG: _getSizesForSubcategory called. Selected subcategory: ${_selectedSubcategory?.name}',
    );
    if (_selectedSubcategory == null) return [];

    switch (_selectedSubcategory!.name) {
      case 'Жіночий одяг':
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      case 'Жіноче взуття':
        return ['34', '35', '36', '37', '38', '39', '40', '41', '42'];
      case 'Чоловічий одяг':
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      case 'Чоловіче взуття':
        return ['39', '40', '41', '42', '43', '44', '45', '46', '47'];
      case 'Жіноча білизна та купальники':
        return ['XS', 'S', 'M', 'L', 'XL'];
      case 'Чоловіча білизна та плавки':
        return ['S', 'M', 'L', 'XL', 'XXL'];
      case 'Одяг для вагітних':
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
      case 'Спецодяг':
        return ['S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      case 'Спецвзуття та аксесуари':
        return [
          '38',
          '39',
          '40',
          '41',
          '42',
          '43',
          '44',
          '45',
          '46',
          '47',
          '48',
        ];
      default:
        return [];
    }
  }

  Widget _buildAreaField() {
    // Показуємо поле тільки для нерухомості та житла подобово
    if (_selectedSubcategory == null) return const SizedBox.shrink();

    bool shouldShowAreaField = false;

    // Перевіряємо чи це нерухомість
    if (_selectedCategory?.name == 'Нерухомість') {
      shouldShowAreaField = true;
    }

    // Перевіряємо чи це житло подобово
    if (_selectedCategory?.name == 'Житло подобово') {
      shouldShowAreaField = true;
    }

    if (!shouldShowAreaField) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Кількість м²',
                style: TextStyle(
                  color: const Color(0xFF09090B),
                  fontSize: 14,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  height: 1.40,
                  letterSpacing: 0.14,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 44, // Фіксована висота 44 пікселі
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _areaController,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  hintStyle: AppTextStyles
                                                      .body1Regular
                                                      .copyWith(
                                                        color: AppColors.color5,
                                                      ),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                                style: AppTextStyles
                                                    .body1Regular
                                                    .copyWith(
                                                      color: AppColors.color2,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              'м²',
                                              style: AppTextStyles.body1Regular
                                                  .copyWith(
                                                    color: AppColors.color8,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSizeSelector() {
    // Показуємо селектор розмірів тільки для категорії "Мода і стиль"
    if (_selectedCategory?.name != 'Мода і стиль')
      return const SizedBox.shrink();

    final sizes = _getSizesForSubcategory();
    if (sizes.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Розмір',
                style: AppTextStyles.body2Medium.copyWith(
                  color: AppColors.color8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 8,
                children: sizes.map((size) {
                  final isSelected = _selectedSize == size;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSize = isSelected ? null : size;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(200),
                        border: Border.all(
                          color: isSelected
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
                      child: Text(
                        size,
                        style: AppTextStyles.body2Semibold.copyWith(
                          color: isSelected ? Colors.white : AppColors.color8,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAgeField() {
    // Показуємо поле віку тільки для категорії "Знайомства"
    if (_selectedCategory?.name != 'Знайомства') return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вік',
                style: AppTextStyles.body2Medium.copyWith(
                  color: AppColors.color8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 44, // Фіксована висота 44 пікселі
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _ageController,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                decoration: InputDecoration(
                                                  hintText: '18',
                                                  hintStyle: AppTextStyles
                                                      .body1Regular
                                                      .copyWith(
                                                        color: AppColors.color5,
                                                      ),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                                style: AppTextStyles
                                                    .body1Regular
                                                    .copyWith(
                                                      color: AppColors.color2,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
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
              border: Border.all(
                color: _submitted && _selectedMake == null
                    ? Colors.red
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
            _isMakeOpen = false;
            _makeSearchController.clear();
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
              border: Border.all(
                color: _submitted && _selectedModel == null
                    ? Colors.red
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
            _isModelOpen = false;
            _modelSearchController.clear();
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
              border: Border.all(
                color: _submitted && _selectedStyle == null
                    ? Colors.red
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
            _isStyleOpen = false;
            _styleSearchController.clear();
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
              border: Border.all(
                color: _submitted && _selectedModelYear == null
                    ? Colors.red
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

  void _showCarBrandPicker() {
    final brands = _getCarBrands();

    // Знаходимо позицію інпуту за допомогою GlobalKey
    final RenderBox? renderBox =
        _carBrandKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned(
              top:
                  position.dy +
                  52, // Позиція інпуту + висота інпуту (44) + відступ (8)
              left: 13,
              right: 13,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(maxHeight: 270),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: brands.length,
                    itemBuilder: (context, index) {
                      final brand = brands[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCarBrand = brand;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            brand,
                            style: AppTextStyles.body1Regular.copyWith(
                              color: AppColors.color2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCarFields() {
    // Показуємо поля авто тільки для категорії "Авто"
    if (_selectedCategory?.name != 'Авто') return const SizedBox.shrink();

    // Для "Легкові автомобілі" та "Автомобілі з Польщі" рік вибирається через дропдаун,
    // тому не показуємо текстовий інпут року
    final isPassengerCar =
        _selectedSubcategory?.name == 'Легкові автомобілі' ||
        _selectedSubcategory?.name == 'Автомобілі з Польщі';

    return Column(
      children: [
        // Рік випуску (тільки для інших підкатегорій авто, не для легкових)
        if (!isPassengerCar)
          Container(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Рік випуску',
                  style: AppTextStyles.body2Medium.copyWith(
                    color: AppColors.color8,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '1999',
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
                  ),
                ),
              ],
            ),
          ),
        if (!isPassengerCar) const SizedBox(height: 8),

        // Пробіг (тис. км)
        Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Пробіг (тис. км)',
                style: AppTextStyles.body2Medium.copyWith(
                  color: AppColors.color8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                  controller: _mileageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                    signed: false,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixText: 'тис. км',
                    suffixStyle: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color5,
                    ),
                  ),
                  style: AppTextStyles.body1Regular.copyWith(
                    color: AppColors.color2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
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
                      vertical: 10,
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
                    child: Center(
                      child: Text(
                        'Продаж',
                        style: AppTextStyles.body2Semibold.copyWith(
                          color: _realEstateType == 'sale'
                              ? AppColors.color2
                              : AppColors.color7,
                        ),
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
                      vertical: 10,
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
                    child: Center(
                      child: Text(
                        'Оренда',
                        style: AppTextStyles.body2Semibold.copyWith(
                          color: _realEstateType == 'rent'
                              ? AppColors.color2
                              : AppColors.color7,
                        ),
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
    print(
      'DEBUG: _buildSizeSelection called. Selected category: ${_selectedCategory?.name}',
    );
    final sizes = _getSizesForSubcategory();
    print('DEBUG: Sizes returned by _getSizesForSubcategory: $sizes');
    if (sizes.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Розмір',
                style: AppTextStyles.body2Medium.copyWith(
                  color: AppColors.color8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 8,
                children: sizes.map((size) {
                  final isSelected = _selectedSize == size;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSize = isSelected ? null : size;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(200),
                        border: Border.all(
                          color: isSelected
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
                      child: Text(
                        size,
                        style: AppTextStyles.body2Semibold.copyWith(
                          color: isSelected ? Colors.white : AppColors.color8,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRadiusRInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  void _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      _priceError = 'Ціна не може бути порожньою';
      return;
    }

    // Remove spaces before parsing
    final cleanValue = value.replaceAll(' ', '');
    final price = double.tryParse(cleanValue);

    if (price == null) {
      _priceError = 'Невірний формат ціни';
    } else if (price <= 0) {
      _priceError = 'Ціна повинна бути більшою за нуль';
    } else {
      _priceError = null;
    }
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

    final RRect rRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final Path path = Path();
    path.addRRect(rRect);

    PathMetrics pathMetrics = path.computeMetrics();
    for (PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is DashedBorderPainter) {
      return oldDelegate.color != color ||
          oldDelegate.strokeWidth != strokeWidth ||
          oldDelegate.dashWidth != dashWidth ||
          oldDelegate.gapWidth != gapWidth ||
          oldDelegate.borderRadius != borderRadius;
    }
    return true;
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    final buffer = StringBuffer();
    int index = 0;

    // Format: (XX) XXX-XX-XX
    if (text.isNotEmpty) {
      buffer.write('(');
      if (text.length >= 2) {
        buffer.write(text.substring(0, 2));
        buffer.write(') ');
        index = 2;
      } else {
        buffer.write(text);
        index = text.length;
      }
    }

    if (text.length > 2) {
      if (text.length >= 5) {
        buffer.write(text.substring(2, 5));
        buffer.write('-');
        index = 5;
      } else {
        buffer.write(text.substring(2));
        index = text.length;
      }
    }

    if (text.length > 5) {
      if (text.length >= 7) {
        buffer.write(text.substring(5, 7));
        buffer.write('-');
        index = 7;
      } else {
        buffer.write(text.substring(5));
        index = text.length;
      }
    }

    if (text.length > 7) {
      buffer.write(text.substring(7, math.min(9, text.length)));
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
