import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zeno/pages/otp_page.dart';
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../widgets/custom_input_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  bool _isLoading = false;
  bool _isPhoneNumberValid = false;
  String? _phoneError;
  final TextEditingController _phoneNumberController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    print('DEBUG (ForgotPassword): initState called');
    // Додаємо слухач для валідації номера телефону
    _phoneNumberController.addListener(_validatePhoneNumber);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print(
      'DEBUG (ForgotPassword): Current route: ${ModalRoute.of(context)?.settings.name}',
    );
  }

  void _validatePhoneNumber() {
    final phoneNumber = _phoneNumberController.text.trim();
    setState(() {
      _isPhoneNumberValid =
          phoneNumber.length == 9; // Українські номери без +380
      if (_isPhoneNumberValid) {
        _phoneError = null; // Очищаємо помилку при валідному номері
      }
    });
  }

  @override
  void dispose() {
    _phoneNumberController.removeListener(_validatePhoneNumber);
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    setState(() {
      _isLoading = true;
      _phoneError = null;
    });

    try {
      final phone = '+380${_phoneNumberController.text.trim()}';
      print(
        'DEBUG (ForgotPassword): Starting password recovery for phone: $phone',
      );

      // Перевіряємо, чи існує користувач з таким номером
      print('DEBUG (ForgotPassword): Checking if user exists in database...');
      final userExists = await _supabase
          .from('profiles')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      print('DEBUG (ForgotPassword): First query result: $userExists');

      final userExistsAlt =
          userExists ??
          await _supabase
              .from('profiles')
              .select()
              .eq('phone', phone.replaceFirst('+', ''))
              .maybeSingle();

      print('DEBUG (ForgotPassword): Alternative query result: $userExistsAlt');

      if (userExists != null || userExistsAlt != null) {
        print('DEBUG (ForgotPassword): User exists, attempting to send SMS...');
        // Користувач існує - відправляємо SMS для відновлення
        try {
          print(
            'DEBUG (ForgotPassword): Calling _supabase.auth.signInWithOtp(phone: $phone)',
          );
          print('DEBUG (ForgotPassword): SMS send time: ${DateTime.now()}');
          await _supabase.auth.signInWithOtp(phone: phone);
          print('DEBUG (ForgotPassword): SMS sent successfully!');

          if (mounted) {
            print('DEBUG (ForgotPassword): Navigating to OtpPage...');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => OtpPage(
                  phoneNumber: phone,
                  isSignUp: false, // Це відновлення, не реєстрація
                ),
              ),
            );
          }
        } catch (otpError) {
          print('ERROR (ForgotPassword): Failed to send SMS: $otpError');
          print(
            'ERROR (ForgotPassword): OTP error type: ${otpError.runtimeType}',
          );

          String errorMessage =
              'Сервіс SMS поки не доступний. Спробуйте пізніше.';

          if (otpError is AuthException) {
            print(
              'ERROR (ForgotPassword): AuthException details: ${otpError.message}',
            );
            print(
              'ERROR (ForgotPassword): AuthException status code: ${otpError.statusCode}',
            );

            // Спеціальна обробка для різних типів помилок SMS
            if (otpError.message.contains('Twilio') ||
                otpError.message.contains('provider') ||
                otpError.statusCode == 422) {
              errorMessage = 'Сервіс SMS поки не доступний. Спробуйте пізніше.';
            } else if (otpError.message.contains('rate limit') ||
                otpError.message.contains('too many')) {
              errorMessage =
                  'Занадто багато спроб. Спробуйте через кілька хвилин.';
            } else if (otpError.message.contains('invalid phone')) {
              errorMessage = 'Невірний формат номера телефону.';
            }
          }

          _showSnackBar(errorMessage, isError: true);
        }
      } else {
        print('DEBUG (ForgotPassword): User not found in database');
        // Користувач не існує
        setState(() {
          _phoneError = 'Не вірний номер користувача.';
        });
      }
    } on AuthException catch (e) {
      print('ERROR (ForgotPassword): AuthException caught: ${e.message}');
      print(
        'ERROR (ForgotPassword): AuthException status code: ${e.statusCode}',
      );
      _showSnackBar('Помилка авторизації: ${e.message}', isError: true);
    } catch (e) {
      print('ERROR (ForgotPassword): Unexpected error: $e');
      print('ERROR (ForgotPassword): Error type: ${e.runtimeType}');
      _showSnackBar('Сталася неочікувана помилка: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('=== CURRENT PAGE: ForgotPasswordPage ===');
    print('=== END PAGE INFO ===');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Логотип
            GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: SvgPicture.asset(
                'assets/icons/zeno-green.svg',
                width: 101,
                height: 24,
              ),
            ),
            const SizedBox(height: 20),

            // Заголовок
            Text(
              'Відновлення PIN-коду',
              style: AppTextStyles.heading2Semibold.copyWith(
                color: AppColors.color2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Підзаголовок
            Text(
              'Введіть номер, на який буде надіслений новий PIN-код',
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Поле введення номера
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(200),
                border: Border.all(
                  color: _phoneError != null
                      ? const Color(0xFFD33E19) // Червоний border при помилці
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
                  SvgPicture.asset(
                    'assets/icons/UA.svg',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+380',
                    style: AppTextStyles.body1Regular.copyWith(
                      color: AppColors.color2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: InputDecoration(
                        hintText: '',
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

            // Текст помилки
            if (_phoneError != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _phoneError!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: 0.14,
                    color: Color(0xFFD33E19),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Кнопка відновлення
            SizedBox(
              width: double.infinity,
              height: 44, // Змінено висоту на 44
              child: ElevatedButton(
                onPressed: (_isLoading || !_isPhoneNumberValid)
                    ? null
                    : _handleForgotPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPhoneNumberValid
                      ? AppColors.primaryColor
                      : const Color(0xFFBFD5DC),
                  disabledBackgroundColor: const Color(0xFFBFD5DC),
                  disabledForegroundColor: Colors.white70,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                    side: BorderSide(
                      color: _isPhoneNumberValid
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ), // Оновлено падінг
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Відновити PIN-код',
                        style: AppTextStyles.body1Medium.copyWith(
                          color: _isPhoneNumberValid
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 14, // Оновлено розмір шрифту
                          fontWeight:
                              FontWeight.w600, // Оновлено товщину шрифту
                          height: 1.40, // Оновлено висоту рядка
                          letterSpacing: 0.14, // Оновлено інтервал між літерами
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
