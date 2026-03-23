import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../services/admin_service.dart';
import 'package:zeno/pages/pin_reset_page.dart'; // Import the new PIN reset page
import 'package:zeno/pages/add_listing_page.dart'; // Import the add listing page
import '../services/sms_autofill_service.dart';
import '../widgets/six_digit_pin_input.dart';

class PinRecoveryOtpPage extends StatefulWidget {
  final String phoneNumber;

  const PinRecoveryOtpPage({super.key, required this.phoneNumber});

  @override
  State<PinRecoveryOtpPage> createState() => _PinRecoveryOtpPageState();
}

class _PinRecoveryOtpPageState extends State<PinRecoveryOtpPage> {
  final TextEditingController _otpController =
      TextEditingController(); // Unified controller
  final FocusNode _otpFocusNode = FocusNode(); // Unified focus node
  final _supabase = Supabase.instance.client;
  final _adminService = AdminService();
  bool _isLoading = false;
  String? _error;
  final ProfileService _profileService = ProfileService();
  final SmsAutofillService _smsService = SmsAutofillService();

  @override
  void initState() {
    super.initState();

    // Ініціалізуємо SMS автозаповнення
    _initializeSmsAutofill();

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

  void _initializeSmsAutofill() async {
    try {
      await _smsService.initialize();
      print(
        'DEBUG (PinRecoveryOtpPage): SMS автозаповнення ініціалізовано (без дозволів)',
      );
    } catch (e) {
      print(
        'ERROR (PinRecoveryOtpPage): Помилка ініціалізації SMS автозаповнення: $e',
      );
    }
  }

  void _showBlockedUserBottomSheet() async {
    final userProfile = await _profileService.getCurrentUserProfile();
    final blockReason = userProfile?['block_reason'];

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
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

  Future<void> _verifyOtp([String? otpCode]) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final otp = otpCode ?? _otpController.text.trim();

      print('Verifying OTP for PIN recovery: $otp'); // Updated log

      final authResponse = await _supabase.auth.verifyOTP(
        phone: widget.phoneNumber,
        token: otp,
        type: OtpType.sms,
      );

      if (authResponse.session != null) {
        if (mounted) {
          // User is now authenticated, update PIN to the OTP code
          try {
            await _supabase.auth.updateUser(UserAttributes(password: otp));

            // Додатково зберігаємо пароль в поле cupcop
            try {
              final currentUser = _supabase.auth.currentUser;
              if (currentUser != null) {
                print(
                  'DEBUG (PinRecoveryOtpPage): Updating cupcop with OTP: $otp',
                );
                final updateResult = await _supabase
                    .from('profiles')
                    .update({'cupcop': otp})
                    .eq('id', currentUser.id);
                print(
                  'DEBUG (PinRecoveryOtpPage): Cupcop update result: $updateResult',
                );
                print(
                  'DEBUG (PinRecoveryOtpPage): Password and cupcop updated successfully',
                );
              }
            } catch (e) {
              print(
                'WARNING (PinRecoveryOtpPage): Failed to update cupcop: $e',
              );
            }

            // Sign out для безпеки - користувач має увійти з новим паролем
            await _supabase.auth.signOut();

            _showSnackBar(
              'PIN-код успішно відновлено! Будь ласка, увійдіть знову.',
            );

            // Переходимо на сторінку логіну замість повернення
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/auth', (route) => false);
            }
          } catch (updateError) {
            print('ERROR updating PIN: $updateError');
            _showSnackBar('Помилка оновлення PIN-коду', isError: true);
          }
        }
      } else {
        _showSnackBar('Помилка верифікації коду.', isError: true);
      }
    } on AuthException catch (e) {
      print('Auth Exception in PIN recovery OTP: ${e.message}'); // Updated log
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      print('Unexpected Error in PIN recovery OTP: $e'); // Updated log
      _showSnackBar('Сталася неочікувана помилка', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    _smsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              'Відновлення PIN-коду', // Updated title
              style: AppTextStyles.heading2Semibold.copyWith(
                color: AppColors.color2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ми надіслали Вам код на номер ${widget.phoneNumber}', // Updated subtitle
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SixDigitPinInput(
              pinController: _otpController,
              pinFocusNode: _otpFocusNode,
              errorText: _error,
              onPinCompleted: (pin) => _verifyOtp(),
              length: 6,
            ),
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
                print('DEBUG (PinRecoveryOtpPage): Resending OTP requested');
                print(
                  'DEBUG (PinRecoveryOtpPage): Phone number: ${widget.phoneNumber}',
                );
                try {
                  await _supabase.auth.signInWithOtp(phone: widget.phoneNumber);
                  print('DEBUG (PinRecoveryOtpPage): OTP resent successfully');
                  _showSnackBar('SMS відправлено повторно');
                } catch (e) {
                  print('ERROR (PinRecoveryOtpPage): Failed to resend OTP: $e');

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
                'Надіслати повторно', // Updated text
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
}
