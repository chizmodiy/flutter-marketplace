import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zeno/pages/otp_page.dart';
import 'package:zeno/pages/pin_login_page.dart';
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../widgets/custom_input_field.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showSignUp = true; // true for Sign Up, false for Log In
  bool _isLoading = false;
  bool _isAuthorized = false;
  bool _isPhoneNumberValid = false; // Додаємо стан для валідації номера
  String? _phoneError; // Додаємо стан для помилки номера телефону
  final TextEditingController _phoneNumberController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _isAuthorized = user != null;

    // Додаємо слухач для валідації номера телефону
    _phoneNumberController.addListener(_validatePhoneNumber);

    if (_isAuthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
    }

    // Перевіряємо статус користувача після завантаження
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isAuthorized) {
        final userStatus = await _profileService.getUserStatus();
        if (userStatus == 'blocked') {
          _showBlockedUserBottomSheet();
        }
      }
    });
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

  void _toggleAuthMode() {
    setState(() {
      _showSignUp = !_showSignUp;
    });
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

  Future<void> _handleSignUp() async {
    setState(() {
      _isLoading = true;
      _phoneError = null; // Очищаємо попередні помилки
    });
    try {
      final phone = '+380${_phoneNumberController.text.trim()}';

      // Перевіряємо, чи існує користувач з таким номером
      final existingUser = await _supabase
          .from('profiles')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      // Якщо не знайшли з +, пробуємо без +
      final existingUserAlt =
          existingUser ??
          await _supabase
              .from('profiles')
              .select()
              .eq('phone', phone.replaceFirst('+', ''))
              .maybeSingle();

      if (existingUser != null || existingUserAlt != null) {
        // Користувач вже існує - показуємо помилку
        setState(() {
          _phoneError = 'Цей номер телефону вже зареєстровано.';
        });
        return; // Зупиняємо виконання, якщо користувач існує
      }

      // Якщо користувач не існує, продовжуємо реєстрацію
      try {
        await _supabase.auth.signInWithOtp(phone: phone);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  OtpPage(phoneNumber: phone, isSignUp: _showSignUp),
            ),
          );
        }
      } catch (smsError) {
        String errorMessage =
            'Сервіс SMS поки не доступний. Спробуйте пізніше.';

        if (smsError is AuthException) {
          if (smsError.message.contains('Twilio') ||
              smsError.message.contains('provider') ||
              smsError.statusCode == 422) {
            errorMessage = 'Сервіс SMS поки не доступний. Спробуйте пізніше.';
          } else if (smsError.message.contains('rate limit') ||
              smsError.message.contains('too many')) {
            errorMessage =
                'Занадто багато спроб. Спробуйте через кілька хвилин.';
          } else if (smsError.message.contains('invalid phone')) {
            errorMessage = 'Невірний формат номера телефону.';
          }
        }

        _showSnackBar(errorMessage, isError: true);
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      _showSnackBar('Сталася неочікувана помилка', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogIn() async {
    setState(() {
      _isLoading = true;
      _phoneError = null; // Очищаємо попередні помилки
    });
    try {
      final phone = '+380${_phoneNumberController.text.trim()}';
      print('Checking user exists for phone: $phone'); // Додаємо лог

      // Перевіряємо, чи існує користувач з таким номером в profiles
      final userExists = await _supabase
          .from('profiles')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      // Якщо не знайшли з +, спробуємо без +
      final userExistsAlt =
          userExists ??
          await _supabase
              .from('profiles')
              .select()
              .eq('phone', phone.replaceFirst('+', ''))
              .maybeSingle();

      print('User exists result: $userExists'); // Додаємо лог
      print('User exists alternative result: $userExistsAlt'); // Додаємо лог

      if (userExists != null || userExistsAlt != null) {
        print(
          'User exists, navigating to PIN login WITHOUT sending SMS',
        ); // Додаємо лог
        // Якщо користувач існує, переходимо на сторінку входу за PIN-кодом БЕЗ відправки SMS
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PinLoginPage(phoneNumber: phone),
            ),
          );
        }
      } else {
        // Користувач не існує - показуємо помилку замість відправки OTP
        setState(() {
          _phoneError = 'Не вірний номер користувача.';
        });
        return;
      }
    } on AuthException catch (e) {
      print('Auth Exception in login: ${e.message}'); // Додаємо лог
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      print('Unexpected error in login: $e'); // Додаємо лог
      _showSnackBar('Сталася неочікувана помилка', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneNumberController.removeListener(_validatePhoneNumber);
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _showBlockedUserBottomSheet() async {
    // Отримуємо профіль користувача з причиною блокування
    final userProfile = await _profileService.getCurrentUserProfile();
    final blockReason = userProfile?['block_reason'];

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false, // Неможливо закрити
        enableDrag: false, // Неможливо перетягувати
        builder: (context) => BlockedUserBottomSheet(blockReason: blockReason),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('=== CURRENT PAGE: AuthPage ===');
    print('ShowSignUp: $_showSignUp');
    print('=== END PAGE INFO ===');
    return Scaffold(
      backgroundColor: Colors.white, // Set background color to white
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: !_isAuthorized
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/');
                },
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 80.0,
        ), // 80px from top
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_showSignUp)
              _buildSignUpForm(context)
            else
              _buildLogInForm(context),
            const SizedBox(height: 40),
            _buildAuthToggleButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        Text(
          'Створити акаунт',
          style: AppTextStyles.heading2Semibold.copyWith(
            color: AppColors.color2,
          ), // Use color2 for Black
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white, // Білий колір
            borderRadius: BorderRadius.circular(200),
            border: Border.all(
              color: _phoneError != null
                  ? const Color(0xFFD33E19) // Червоний border при помилці
                  : AppColors.zinc200,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(
                  16,
                  24,
                  40,
                  0.05,
                ), // rgba(16, 24, 40, 0.05)
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              SvgPicture.asset('assets/icons/UA.svg', width: 20, height: 20),
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
                  ), // Black
                ),
              ),
            ],
          ),
        ),
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
                height: 1.4, // line-height: 140%
                letterSpacing: 0.14, // letter-spacing: 1%
                color: Color(0xFFD33E19),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 44, // Змінюємо висоту на 44
          child: ElevatedButton(
            onPressed: (_isLoading || !_isPhoneNumberValid)
                ? null
                : _handleSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPhoneNumberValid
                  ? AppColors.primaryColor
                  : const Color(
                      0xFFBFD5DC,
                    ), // #BFD5DC колір для неактивних кнопок
              disabledBackgroundColor: const Color(
                0xFFBFD5DC,
              ), // Примусово встановлюємо колір для disabled стану
              disabledForegroundColor:
                  Colors.white70, // Колір тексту для disabled стану
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(200),
                side: BorderSide(
                  color: _isPhoneNumberValid
                      ? AppColors.primaryColor
                      : Colors.transparent, // 100% прозорий border
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
                    'Зареєструватися',
                    style: AppTextStyles.body1Medium.copyWith(
                      color: _isPhoneNumberValid
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 14, // Оновлено розмір шрифту
                      fontWeight: FontWeight.w600, // Оновлено товщину шрифту
                      height: 1.40, // Оновлено висоту рядка
                      letterSpacing: 0.14, // Оновлено інтервал між літерами
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogInForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        Text(
          'Увійти',
          style: AppTextStyles.heading2Semibold.copyWith(
            color: AppColors.color2,
          ), // Use color2 for Black
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white, // Білий колір
            borderRadius: BorderRadius.circular(200),
            border: Border.all(
              color: _phoneError != null
                  ? const Color(0xFFD33E19) // Червоний border при помилці
                  : AppColors.zinc200,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(
                  16,
                  24,
                  40,
                  0.05,
                ), // rgba(16, 24, 40, 0.05)
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              SvgPicture.asset('assets/icons/UA.svg', width: 20, height: 20),
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
                  ), // Black
                ),
              ),
            ],
          ),
        ),
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
                height: 1.4, // line-height: 140%
                letterSpacing: 0.14, // letter-spacing: 1%
                color: Color(0xFFD33E19),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 44, // Змінюємо висоту на 44
          child: ElevatedButton(
            onPressed: (_isLoading || !_isPhoneNumberValid)
                ? null
                : _handleLogIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPhoneNumberValid
                  ? AppColors.primaryColor
                  : const Color(
                      0xFFBFD5DC,
                    ), // #BFD5DC колір для неактивних кнопок
              disabledBackgroundColor: const Color(
                0xFFBFD5DC,
              ), // Примусово встановлюємо колір для disabled стану
              disabledForegroundColor:
                  Colors.white70, // Колір тексту для disabled стану
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(200),
                side: BorderSide(
                  color: _isPhoneNumberValid
                      ? AppColors.primaryColor
                      : Colors.transparent, // 100% прозорий border
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
                    'Увійти',
                    style: AppTextStyles.body1Medium.copyWith(
                      color: _isPhoneNumberValid
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 14, // Оновлено розмір шрифту
                      fontWeight: FontWeight.w600, // Оновлено товщину шрифту
                      height: 1.40, // Оновлено висоту рядка
                      letterSpacing: 0.14, // Оновлено інтервал між літерами
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthToggleButton(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _showSignUp ? 'У Вас є акаунт? ' : 'Немає акаунта? ',
          style: AppTextStyles.body2Regular.copyWith(
            color: AppColors.color8,
          ), // Zinc-600
        ),
        TextButton(
          onPressed: _toggleAuthMode,
          style: ButtonStyle(
            // Using ButtonStyle for more control over states
            padding: WidgetStateProperty.all(EdgeInsets.zero),
            minimumSize: WidgetStateProperty.all(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            splashFactory: NoSplash.splashFactory, // Remove splash effect
            overlayColor: WidgetStateProperty.all(
              Colors.transparent,
            ), // Remove overlay/highlight effect
          ),
          child: Text(
            _showSignUp ? 'Увійти' : 'Зареєструватися',
            style: AppTextStyles.body1Medium.copyWith(
              color: AppColors.primaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
