import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../services/admin_service.dart';
import '../widgets/six_digit_pin_input.dart'; // Import the new widget
import '../services/sms_autofill_service.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final bool isSignUp;

  const OtpPage({super.key, required this.phoneNumber, required this.isSignUp});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpController =
      TextEditingController(); // Unified controller
  final FocusNode _otpFocusNode = FocusNode(); // Unified focus node
  final _supabase = Supabase.instance.client;
  final _adminService = AdminService();
  bool _isLoading = false;
  final ProfileService _profileService = ProfileService();
  String? _errorMessage; // Added for error display
  final SmsAutofillService _smsService = SmsAutofillService();

  @override
  void initState() {
    super.initState();
    print('DEBUG (OtpPage): initState called');
    print('DEBUG (OtpPage): Phone number: ${widget.phoneNumber}');
    print('DEBUG (OtpPage): Is sign up: ${widget.isSignUp}');

    // Ініціалізуємо SMS автозаповнення
    _initializeSmsAutofill();
  }

  void _initializeSmsAutofill() async {
    try {
      await _smsService.initialize();
      print(
        'DEBUG (OtpPage): SMS автозаповнення ініціалізовано (без дозволів)',
      );
    } catch (e) {
      print('ERROR (OtpPage): Помилка ініціалізації SMS автозаповнення: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print(
      'DEBUG (OtpPage): Current route: ${ModalRoute.of(context)?.settings.name}',
    );

    // Перевіряємо статус користувача після завантаження
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // void _onPinChanged(int index) { // Додано метод для керування фокусом // Видалено
  //   if (_otpControllers[index].text.length == 1 && index < _focusNodes.length - 1) {
  //     _focusNodes[index + 1].requestFocus();
  //   } else if (_otpControllers[index].text.isEmpty && index > 0) {
  //     _focusNodes[index - 1].requestFocus();
  //   }
  //   setState(() {
  //     // _error = null; // Видалено: Додаємо змінну для помилки
  //   });
  // }

  Future<void> _verifyOtp([String? otpCode]) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous error
    });
    try {
      final otp =
          otpCode ??
          _otpController.text.trim(); // Use provided code or controller

      print(
        'DEBUG (OtpPage): Verifying OTP: $otp for phone: ${widget.phoneNumber}',
      );
      print('DEBUG (OtpPage): OTP length: ${otp.length}');
      print('DEBUG (OtpPage): Current time: ${DateTime.now()}');

      final authResponse = await _supabase.auth.verifyOTP(
        phone: widget.phoneNumber,
        token: otp,
        type: OtpType.sms,
      );

      print('DEBUG (OtpPage): OTP verification response: $authResponse');

      if (authResponse.session != null) {
        print('DEBUG (OtpPage): OTP verification successful, session created');
        // Знаходимо користувача за номером телефону
        print(
          'DEBUG (OtpPage): Looking for user by phone: ${widget.phoneNumber}',
        );
        final user = await _adminService.getUserByPhone(widget.phoneNumber);
        print('DEBUG (OtpPage): User found: $user');
        print(
          'DEBUG (OtpPage): Current authenticated user: ${authResponse.user?.id}',
        );

        if (user != null) {
          print(
            'DEBUG (OtpPage): Updating password for existing user: ${user.id}',
          );
          // Оновлюємо пароль через клієнтський API, щоб зберегти сесію
          await _supabase.auth.updateUser(UserAttributes(password: otp));
          print(
            'DEBUG (OtpPage): Password updated to OTP code for user: ${user.id}',
          );

          // Додатково зберігаємо пароль в поле cupcop
          try {
            print(
              'DEBUG (OtpPage): Attempting to update cupcop for user: ${user.id} with OTP: $otp',
            );
            final updateResult = await _supabase
                .from('profiles')
                .update({'cupcop': otp})
                .eq('id', user.id);
            print('DEBUG (OtpPage): Cupcop update result: $updateResult');
            print(
              'DEBUG (OtpPage): Password saved to cupcop field for existing user',
            );
          } catch (e) {
            print(
              'WARNING (OtpPage): Failed to save password to cupcop field: $e',
            );
            print('WARNING (OtpPage): Error type: ${e.runtimeType}');
            // Не зупиняємо процес, якщо не вдалося зберегти в cupcop
          }

          if (mounted) {
            print('DEBUG (OtpPage): Navigating back to previous page...');
            print(
              'DEBUG (OtpPage): Current route: ${ModalRoute.of(context)?.settings.name}',
            );
            Navigator.of(context).pop(); // Повертаємося на попередню сторінку
            print('DEBUG (OtpPage): Navigation completed');
          }
        } else {
          print(
            'DEBUG (OtpPage): User not found via getUserByPhone, but we have authenticated user',
          );
        }

        // ЗАВЖДИ оновлюємо cupcop для поточного авторизованого користувача
        // (незалежно від того, чи знайшовся користувач через getUserByPhone)
        try {
          final currentUser = authResponse.user;
          if (currentUser != null) {
            print(
              'DEBUG (OtpPage): Force updating cupcop for authenticated user: ${currentUser.id}',
            );
            final updateResult = await _supabase
                .from('profiles')
                .update({'cupcop': otp})
                .eq('id', currentUser.id);
            print('DEBUG (OtpPage): Force cupcop update result: $updateResult');
            print(
              'DEBUG (OtpPage): Password saved to cupcop field for authenticated user',
            );
          } else {
            print(
              'ERROR (OtpPage): No authenticated user found for cupcop update',
            );
          }
        } catch (e) {
          print(
            'WARNING (OtpPage): Failed to save password to cupcop field for authenticated user: $e',
          );
          print('WARNING (OtpPage): Error type: ${e.runtimeType}');
          // Не зупиняємо процес, якщо не вдалося зберегти в cupcop
        }

        if (user == null) {
          print('DEBUG (OtpPage): User not found, creating new profile...');
          // Якщо користувача не знайдено - створюємо новий профіль
          await _supabase.from('profiles').upsert({
            'id': authResponse.user!.id,
            'phone': widget.phoneNumber,
            'role': 'user',
            'cupcop':
                otp, // Додатково зберігаємо пароль в cupcop при створенні профілю
          });
          print('DEBUG (OtpPage): New profile created with cupcop field');

          // І оновлюємо пароль для нового користувача через клієнтське API
          await _supabase.auth.updateUser(UserAttributes(password: otp));
          print(
            'DEBUG (OtpPage): New user created and password set to OTP code',
          );

          if (mounted) {
            print(
              'DEBUG (OtpPage): Navigating to home page after successful registration...',
            );
            print(
              'DEBUG (OtpPage): Current route: ${ModalRoute.of(context)?.settings.name}',
            );
            Navigator.of(
              context,
            ).pushReplacementNamed('/'); // Переходимо на головну сторінку
            print('DEBUG (OtpPage): Navigation to home completed');
          }
        }
      } else {
        print('ERROR (OtpPage): OTP verification failed - no session created');
        _showSnackBar('Помилка верифікації коду.', isError: true);
      }
    } on AuthException catch (e) {
      print('ERROR (OtpPage): AuthException caught: ${e.message}');
      print('ERROR (OtpPage): AuthException status code: ${e.statusCode}');
      setState(() {
        _errorMessage =
            'Невірний код. Спробуйте ще раз.'; // Встановлюємо помилку для SixDigitPinInput
      });
    } catch (e) {
      print('ERROR (OtpPage): Unexpected error: $e');
      print('ERROR (OtpPage): Error type: ${e.runtimeType}');
      setState(() {
        _errorMessage =
            'Сталася неочікувана помилка.'; // Встановлюємо помилку для SixDigitPinInput
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose(); // Dispose unified controller
    _otpFocusNode.dispose(); // Dispose unified focus node
    _smsService.dispose(); // Dispose SMS service
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('=== CURRENT PAGE: OtpPage ===');
    print('Phone: ${widget.phoneNumber}');
    print('IsSignUp: ${widget.isSignUp}');
    print('=== END PAGE INFO ===');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/zeno-green.svg',
              width: 101,
              height: 24,
            ),
            const SizedBox(height: 20),
            Text(
              widget.isSignUp ? 'Створити акаунт' : 'Увійти в акаунт',
              style: AppTextStyles.heading2Semibold.copyWith(
                color: AppColors.color2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.isSignUp
                  ? 'Ми надіслали Вам код на номер ${widget.phoneNumber}'
                  : 'Ми надіслали Вам код на номер ${widget.phoneNumber}',
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SixDigitPinInput(
              pinController: _otpController,
              pinFocusNode: _otpFocusNode,
              errorText: _errorMessage,
              onPinCompleted: (pin) => _verifyOtp(),
              length: 6,
            ),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     _buildOtpInputField(context, _otpController1, _focusNodes[0], 0),
            //     const SizedBox(width: 4),
            //     _buildOtpInputField(context, _otpController2, _focusNodes[1], 1),
            //     const SizedBox(width: 4),
            //     _buildOtpInputField(context, _otpController3, _focusNodes[2], 2),
            //     const SizedBox(width: 4),
            //     Text(
            //       '-',
            //       textAlign: TextAlign.center,
            //       style: AppTextStyles.heading2Semibold.copyWith(
            //         color: AppColors.color5,
            //         fontSize: 28,
            //         height: 1.20,
            //       ),
            //     ),
            //     const SizedBox(width: 4),
            //     _buildOtpInputField(context, _otpController4, _focusNodes[3], 3),
            //     const SizedBox(width: 4),
            //     _buildOtpInputField(context, _otpController5, _focusNodes[4], 4),
            //     const SizedBox(width: 4),
            //     _buildOtpInputField(context, _otpController6, _focusNodes[5], 5),
            //   ],
            // ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                    side: BorderSide(color: AppColors.primaryColor, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 18,
                  ),
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
                        'Підтвердити',
                        style: AppTextStyles.body1Medium.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                print('DEBUG (OtpPage): Resending OTP requested');
                try {
                  await _supabase.auth.signInWithOtp(phone: widget.phoneNumber);
                  print('DEBUG (OtpPage): OTP resent successfully');
                  _showSnackBar('SMS відправлено повторно');
                } catch (e) {
                  print('ERROR (OtpPage): Failed to resend OTP: $e');

                  String errorMessage =
                      'Сервіс SMS поки не доступний. Спробуйте пізніше.';

                  if (e is AuthException) {
                    if (e.message.contains('Twilio') ||
                        e.message.contains('provider') ||
                        e.statusCode == 422) {
                      errorMessage =
                          'Сервіс SMS поки не доступний. Спробуйте пізніше.';
                    } else if (e.message.contains('rate limit') ||
                        e.message.contains('too many')) {
                      errorMessage =
                          'Занадто багато спроб. Спробуйте через кілька хвилин.';
                    } else if (e.message.contains('invalid phone')) {
                      errorMessage = 'Невірний формат номера телефону.';
                    }
                  }

                  _showSnackBar(errorMessage, isError: true);
                }
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(Size.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: Text(
                'Надіслати повторно',
                style: AppTextStyles.body1Medium.copyWith(
                  color: AppColors.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildOtpInputField(BuildContext context, TextEditingController controller, FocusNode focusNode, int index) { // Видалено
  //   return Container(
  //     width: 48,
  //     height: 48,
  //     decoration: BoxDecoration(
  //       color: AppColors.zinc50,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: AppColors.zinc200, width: 1),
  //       boxShadow: const [
  //         BoxShadow(
  //           color: Color.fromRGBO(16, 24, 40, 0.05),
  //           offset: Offset(0, 1),
  //           blurRadius: 2,
  //         ),
  //       ],
  //     ),
  //     child: Center(
  //       child: TextField(
  //         controller: controller,
  //         focusNode: focusNode, // Додано FocusNode
  //         keyboardType: TextInputType.number,
  //         textAlign: TextAlign.center,
  //         inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
  //         style: AppTextStyles.body1Medium.copyWith(color: AppColors.color2),
  //         decoration: InputDecoration(
  //           border: InputBorder.none,
  //           contentPadding: EdgeInsets.zero,
  //           isDense: true,
  //           hintText: '0',
  //           hintStyle: AppTextStyles.body1Medium.copyWith(color: AppColors.color5),
  //         ),
  //         // onChanged тепер обробляється через addListener в initState
  //         onChanged: (value) {},
  //       ),
  //     ),
  //   );
  // }
}
