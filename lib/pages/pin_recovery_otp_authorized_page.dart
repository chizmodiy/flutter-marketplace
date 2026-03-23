import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../widgets/blocked_user_bottom_sheet.dart';
import 'package:zeno/pages/pin_reset_page.dart'; // Import the PIN reset page
import 'package:zeno/pages/add_listing_page.dart'; // Import the add listing page

class PinRecoveryOtpAuthorizedPage extends StatefulWidget {
  final String phoneNumber;

  const PinRecoveryOtpAuthorizedPage({super.key, required this.phoneNumber});

  @override
  State<PinRecoveryOtpAuthorizedPage> createState() =>
      _PinRecoveryOtpAuthorizedPageState();
}

class _PinRecoveryOtpAuthorizedPageState
    extends State<PinRecoveryOtpAuthorizedPage> {
  final TextEditingController _otpController1 = TextEditingController();
  final TextEditingController _otpController2 = TextEditingController();
  final TextEditingController _otpController3 = TextEditingController();
  final TextEditingController _otpController4 = TextEditingController();
  final TextEditingController _otpController5 = TextEditingController();
  final TextEditingController _otpController6 = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;
  final ProfileService _profileService = ProfileService();
  String? _userPhoneNumber;

  // Helper function to normalize phone number
  String? _normalizePhoneNumber(String? phone) {
    if (phone == null) return null;

    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If it starts with +380, return as is
    if (cleaned.startsWith('+380')) {
      return cleaned;
    }

    // If it starts with 380, add +
    if (cleaned.startsWith('380')) {
      return '+$cleaned';
    }

    // If it's 9 digits, add +380
    if (cleaned.length == 9 && !cleaned.startsWith('380')) {
      return '+380$cleaned';
    }

    return phone; // Return original if can't normalize
  }

  @override
  void initState() {
    super.initState();

    // Use the passed phone number
    _userPhoneNumber = _normalizePhoneNumber(widget.phoneNumber);
    print(
      'DEBUG (PinRecoveryOtpAuthorizedPage): Passed phone: ${widget.phoneNumber}',
    );
    print(
      'DEBUG (PinRecoveryOtpAuthorizedPage): Normalized phone: $_userPhoneNumber',
    );

    // Get current user info for debugging
    final currentUser = _supabase.auth.currentUser;
    print(
      'DEBUG (PinRecoveryOtpAuthorizedPage): Current user: ${currentUser?.id}',
    );
    print(
      'DEBUG (PinRecoveryOtpAuthorizedPage): User phone: ${currentUser?.phone}',
    );
    print(
      'DEBUG (PinRecoveryOtpAuthorizedPage): User email: ${currentUser?.email}',
    );

    // Note: We don't check for blocked users here since we're using passed phone number
    // and the user might be logged out after SMS sending
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

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final otp =
          _otpController1.text.trim() +
          _otpController2.text.trim() +
          _otpController3.text.trim() +
          _otpController4.text.trim() +
          _otpController5.text.trim() +
          _otpController6.text.trim();

      print(
        'DEBUG (PinRecoveryOtpAuthorizedPage): Verifying OTP for authorized PIN recovery: $otp',
      );
      print(
        'DEBUG (PinRecoveryOtpAuthorizedPage): User phone number: $_userPhoneNumber',
      );

      if (_userPhoneNumber == null) {
        print('ERROR (PinRecoveryOtpAuthorizedPage): No phone number found');
        _showSnackBar('Номер телефону не знайдено.', isError: true);
        return;
      }

      print(
        'DEBUG (PinRecoveryOtpAuthorizedPage): Attempting to verify OTP with phone: $_userPhoneNumber',
      );

      final authResponse = await _supabase.auth.verifyOTP(
        phone: _userPhoneNumber!,
        token: otp,
        type: OtpType.sms,
      );

      print('DEBUG (PinRecoveryOtpAuthorizedPage): OTP verification response:');
      print(
        'DEBUG (PinRecoveryOtpAuthorizedPage): Session: ${authResponse.session != null ? 'present' : 'missing'}',
      );
      print(
        'DEBUG (PinRecoveryOtpAuthorizedPage): User: ${authResponse.user != null ? 'present' : 'missing'}',
      );

      if (authResponse.session != null) {
        if (mounted) {
          // User is now authenticated, update PIN to the OTP code
          try {
            await _supabase.auth.updateUser(UserAttributes(password: otp));

            // Додатково зберігаємо пароль в поле cupcop
            try {
              final currentUser = _supabase.auth.currentUser;
              print(
                'DEBUG (PinRecoveryOtpAuthorizedPage): Current user for cupcop update: ${currentUser?.id}',
              );
              if (currentUser != null) {
                print(
                  'DEBUG (PinRecoveryOtpAuthorizedPage): Attempting to update cupcop with OTP: $otp',
                );
                final updateResult = await _supabase
                    .from('profiles')
                    .update({'cupcop': otp})
                    .eq('id', currentUser.id);
                print(
                  'DEBUG (PinRecoveryOtpAuthorizedPage): Cupcop update result: $updateResult',
                );
                print('DEBUG: Password saved to cupcop field in recovery');
              } else {
                print(
                  'ERROR (PinRecoveryOtpAuthorizedPage): No current user found for cupcop update',
                );
              }
            } catch (e) {
              print(
                'WARNING: Failed to save password to cupcop field in recovery: $e',
              );
              print('WARNING: Error type: ${e.runtimeType}');
              // Не зупиняємо процес, якщо не вдалося зберегти в cupcop
            }

            // Sign out to prevent session issues
            await _supabase.auth.signOut();

            // ПРИМУСОВО оновлюємо cupcop ПІСЛЯ signOut
            try {
              print(
                'DEBUG (PinRecoveryOtpAuthorizedPage): Force updating cupcop after signOut with OTP: $otp',
              );
              final forceUpdateResult = await _supabase
                  .from('profiles')
                  .update({'cupcop': otp})
                  .eq('id', authResponse.user!.id);
              print(
                'DEBUG (PinRecoveryOtpAuthorizedPage): Force cupcop update result: $forceUpdateResult',
              );
              print(
                'DEBUG (PinRecoveryOtpAuthorizedPage): Cupcop force updated successfully',
              );
            } catch (e) {
              print(
                'WARNING (PinRecoveryOtpAuthorizedPage): Failed to force update cupcop: $e',
              );
            }

            _showSnackBar('PIN-код успішно відновлено!');

            // Return to add listing page
            Navigator.of(context).pop(true);
          } catch (updateError) {
            print('ERROR updating PIN: $updateError');
            _showSnackBar('Помилка оновлення PIN-коду', isError: true);
          }
        }
      } else {
        _showSnackBar('Помилка верифікації коду.', isError: true);
      }
    } on AuthException catch (e) {
      print('Auth Exception in authorized PIN recovery OTP: ${e.message}');
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      print('Unexpected Error in authorized PIN recovery OTP: $e');
      _showSnackBar('Сталася неочікувана помилка', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _otpController1.dispose();
    _otpController2.dispose();
    _otpController3.dispose();
    _otpController4.dispose();
    _otpController5.dispose();
    _otpController6.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('=== CURRENT PAGE: PinRecoveryOtpAuthorizedPage ===');
    print('Phone: ${widget.phoneNumber}');
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
              'Відновлення PIN-коду',
              style: AppTextStyles.heading2Semibold.copyWith(
                color: AppColors.color2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ми надіслали Вам код на номер ${_userPhoneNumber ?? 'ваш номер'}\nЦей код стане вашим новим PIN-кодом',
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOtpInputField(context, _otpController1),
                const SizedBox(width: 3),
                _buildOtpInputField(context, _otpController2),
                const SizedBox(width: 3),
                _buildOtpInputField(context, _otpController3),
                const SizedBox(width: 3),
                _buildOtpInputField(context, _otpController4),
                const SizedBox(width: 3),
                _buildOtpInputField(context, _otpController5),
                const SizedBox(width: 3),
                _buildOtpInputField(context, _otpController6),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
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
                print(
                  'DEBUG (PinRecoveryOtpAuthorizedPage): Resending OTP requested',
                );
                print(
                  'DEBUG (PinRecoveryOtpAuthorizedPage): Phone number: $_userPhoneNumber',
                );
                try {
                  if (_userPhoneNumber != null) {
                    print(
                      'DEBUG (PinRecoveryOtpAuthorizedPage): Attempting to resend OTP to: $_userPhoneNumber',
                    );
                    await _supabase.auth.signInWithOtp(
                      phone: _userPhoneNumber!,
                    );
                    print(
                      'DEBUG (PinRecoveryOtpAuthorizedPage): OTP resent successfully',
                    );
                    _showSnackBar('SMS відправлено повторно');
                  } else {
                    print(
                      'ERROR (PinRecoveryOtpAuthorizedPage): Cannot resend OTP - no phone number',
                    );
                    _showSnackBar('Номер телефону не знайдено', isError: true);
                  }
                } catch (e) {
                  print(
                    'ERROR (PinRecoveryOtpAuthorizedPage): Failed to resend OTP: $e',
                  );

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

  Widget _buildOtpInputField(
    BuildContext context,
    TextEditingController controller,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.zinc50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.zinc200, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(16, 24, 40, 0.05),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: AppTextStyles.body1Medium.copyWith(color: AppColors.color2),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            hintText: '0',
            hintStyle: AppTextStyles.body1Medium.copyWith(
              color: AppColors.color5,
            ),
          ),
          onChanged: (value) {
            if (value.length == 1) {
              FocusScope.of(context).nextFocus();
            }
            if (value.isEmpty) {
              FocusScope.of(context).previousFocus();
            }
          },
        ),
      ),
    );
  }
}
