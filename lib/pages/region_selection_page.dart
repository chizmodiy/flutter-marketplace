import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class RegionSelectionPage extends StatefulWidget {
  final List<Category>? initialSelectedRegions;

  const RegionSelectionPage({super.key, this.initialSelectedRegions});

  @override
  State<RegionSelectionPage> createState() => _RegionSelectionPageState();
}

class _RegionSelectionPageState extends State<RegionSelectionPage> {
  late final List<Category> _regions;
  List<Category> _selectedRegions = [];

  // Функція для правильного порівняння українських рядків
  int _compareUkrainianStrings(String a, String b) {
    // Мапа пріоритетів для українських літер (відповідно до алфавіту)
    final Map<String, int> ukrainianOrder = {
      'А': 1, 'Б': 2, 'В': 3, 'Г': 4, 'Ґ': 5, 'Д': 6, 'Е': 7, 'Є': 8, 'Ж': 9, 'З': 10,
      'И': 11, 'І': 12, 'Ї': 13, 'Й': 14, 'К': 15, 'Л': 16, 'М': 17, 'Н': 18, 'О': 19, 'П': 20,
      'Р': 21, 'С': 22, 'Т': 23, 'У': 24, 'Ф': 25, 'Х': 26, 'Ц': 27, 'Ч': 28, 'Ш': 29, 'Щ': 30,
      'Ю': 31, 'Я': 32, 'а': 1, 'б': 2, 'в': 3, 'г': 4, 'ґ': 5, 'д': 6, 'е': 7, 'є': 8,
      'ж': 9, 'з': 10, 'и': 11, 'і': 12, 'ї': 13, 'й': 14, 'к': 15, 'л': 16, 'м': 17, 'н': 18,
      'о': 19, 'п': 20, 'р': 21, 'с': 22, 'т': 23, 'у': 24, 'ф': 25, 'х': 26, 'ц': 27, 'ч': 28,
      'ш': 29, 'щ': 30, 'ю': 31, 'я': 32,
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
    if (widget.initialSelectedRegions != null) {
      _selectedRegions = List.from(widget.initialSelectedRegions!);
    }
    final regionsList = [
      Category(id: 'kyiv', name: 'Київ'),
      Category(id: 'kyiv_oblast', name: 'Київська область'),
      Category(id: 'kharkiv', name: 'Харківська область'),
      Category(id: 'odesa', name: 'Одеська область'),
      Category(id: 'dnipro', name: 'Дніпропетровська область'),
      Category(id: 'lviv', name: 'Львівська область'),
      Category(id: 'donetsk', name: 'Донецька область'),
      Category(id: 'zaporizhzhia', name: 'Запорізька область'),
      Category(id: 'mykolaiv', name: 'Миколаївська область'),
      Category(id: 'vinnytsia', name: 'Вінницька область'),
      Category(id: 'poltava', name: 'Полтавська область'),
      Category(id: 'sumy', name: 'Сумська область'),
      Category(id: 'khmelnytskyi', name: 'Хмельницька область'),
      Category(id: 'cherkasy', name: 'Черкаська область'),
      Category(id: 'zhytomyr', name: 'Житомирська область'),
      Category(id: 'chernihiv', name: 'Чернігівська область'),
      Category(id: 'kropyvnytskyi', name: 'Кіровоградська область'),
      Category(id: 'rivne', name: 'Рівненська область'),
      Category(id: 'ternopil', name: 'Тернопільська область'),
      Category(id: 'ivano-frankivsk', name: 'Івано-Франківська область'),
      Category(id: 'lutsk', name: 'Волинська область'),
      Category(id: 'uzhhorod', name: 'Закарпатська область'),
      Category(id: 'chernivtsi', name: 'Чернівецька область'),
      Category(id: 'kherson', name: 'Херсонська область'),
      Category(id: 'luhansk', name: 'Луганська область'),
    ];
    // Сортуємо області в алфавітному порядку з урахуванням українського алфавіту
    _regions = List.from(regionsList)
      ..sort((a, b) => _compareUkrainianStrings(a.name, b.name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 1 + 20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.zinc200, width: 1.0),
            ),
          ),
          child: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                  const SizedBox(width: 18),
                  Text(
                    'Оберіть області',
                    style: AppTextStyles.heading2Semibold,
                  ),
                ],
              ),
            ),
            centerTitle: false,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _regions.length,
              itemBuilder: (context, index) {
                final region = _regions[index];
                final isSelected = _selectedRegions.any((r) => r.id == region.id);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedRegions.removeWhere((r) => r.id == region.id);
                      } else {
                        _selectedRegions.add(region);
                      }
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryColor.withValues(alpha: 0.1) : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryColor : AppColors.zinc200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          region.name,
                          style: AppTextStyles.body1Regular.copyWith(
                            color: isSelected ? AppColors.primaryColor : AppColors.zinc950,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check, color: AppColors.primaryColor, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.zinc200, width: 1)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {'categories': _selectedRegions});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Застосувати',
                  style: AppTextStyles.body1Semibold.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
