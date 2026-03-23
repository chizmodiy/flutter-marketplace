import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zeno/pages/pin_recovery_otp_page.dart'; // Changed to new OTP page
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import '../widgets/custom_input_field.dart';

class PinRecoveryPhonePage extends StatefulWidget {
  const PinRecoveryPhonePage({super.key});

  @override
  State<PinRecoveryPhonePage> createState() => _PinRecoveryPhonePageState();
}

class _PinRecoveryPhonePageState extends State<PinRecoveryPhonePage> {
  bool _isLoading = false;
  bool _isPhoneNumberValid = false;
  String? _phoneError;
  final TextEditingController _phoneNumberController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _phoneNumberController.addListener(_validatePhoneNumber);
  }

  void _validatePhoneNumber() {
    final phoneNumber = _phoneNumberController.text.trim();
    setState(() {
      _isPhoneNumberValid = phoneNumber.length == 9;
      if (_isPhoneNumberValid) {
        _phoneError = null;
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
    // Disabled snackbar messages
  }

  Future<void> _handlePinRecovery() async {
    // Renamed method
    setState(() {
      _isLoading = true;
      _phoneError = null;
    });

    try {
      final phone = '+380${_phoneNumberController.text.trim()}';

      final userExists = await _supabase
          .from('profiles')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      final userExistsAlt =
          userExists ??
          await _supabase
              .from('profiles')
              .select()
              .eq('phone', phone.replaceFirst('+', ''))
              .maybeSingle();

      if (userExists != null || userExistsAlt != null) {
        // User exists - send SMS for PIN recovery
        try {
          await _supabase.auth.signInWithOtp(phone: phone);

          if (mounted) {
            final recoverySuccessful = await Navigator.of(context).push(
              // Expecting a result
              MaterialPageRoute(
                builder: (context) => PinRecoveryOtpPage(
                  // Changed to new OTP page
                  phoneNumber: phone,
                ),
              ),
            );
            if (recoverySuccessful == true && mounted) {
              // If PIN recovery was successful, redirect to home page
              Navigator.of(context).pushReplacementNamed('/');
            }
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
      } else {
        // User does not exist
        setState(() {
          _phoneError =
              'Користувача з таким номером не знайдено.'; // Updated error message
        });
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

  @override
  Widget build(BuildContext context) {
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
              'Введіть номер телефону, на який зареєстрований ваш PIN-код', // Updated subtitle
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
                      ? const Color(0xFFD33E19)
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
              height: 44,
              child: ElevatedButton(
                onPressed: (_isLoading || !_isPhoneNumberValid)
                    ? null
                    : _handlePinRecovery, // Renamed handler
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
                        'Відновити PIN-код',
                        style: AppTextStyles.body1Medium.copyWith(
                          color: _isPhoneNumberValid
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.40,
                          letterSpacing: 0.14,
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
