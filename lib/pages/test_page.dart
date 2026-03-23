import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
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
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: Text(
          'Тест',
          style: AppTextStyles.heading2Semibold.copyWith(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сторінка тестування',
              style: AppTextStyles.heading3Semibold.copyWith(
                color: AppColors.color2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Тут будуть тести',
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
