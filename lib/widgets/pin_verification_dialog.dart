import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/forgot_password_page.dart';
import 'package:zeno/pages/pin_recovery_phone_page.dart';
import 'package:zeno/pages/pin_recovery_otp_authorized_page.dart';
import 'six_digit_pin_input.dart';
import 'dart:convert'; // Import for JSON encoding/decoding
import 'package:http/http.dart' as http; // Added for network test

class PinVerificationDialog extends StatefulWidget {
  final Function(String) onPinVerified;
  final String?
  phoneNumber; // Optional: Pass phone number if needed for sign-in

  const PinVerificationDialog({
    super.key,
    required this.onPinVerified,
    this.phoneNumber,
  });

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final TextEditingController _pinController =
      TextEditingController(); // Unified controller
  final FocusNode _pinFocusNode = FocusNode(); // Unified focus node
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // for (int i = 0; i < _pinControllers.length; i++) {
    //   _pinControllers[i].addListener(() => _onPinChanged(i));
    // }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  // void _onPinChanged(int index) { // Видалено
  //   setState(() {
  //     _errorMessage = null;
  //   });
  //   if (_pinControllers[index].text.length == 1) {
  //     if (index < _pinControllers.length - 1) {
  //       _pinFocusNodes[index + 1].requestFocus();
  //     } else {
  //       _pinFocusNodes[index].unfocus();
  //     }
  //   } else if (_pinControllers[index].text.isEmpty && index > 0) {
  //     _pinFocusNodes[index - 1].requestFocus();
  //   }
  // }

  Future<void> _testNetworkConnection() async {
    print('DEBUG (PinVerificationDialog): Testing network connection...');
    try {
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/todos/1'),
      );
      if (response.statusCode == 200) {
        print(
          'DEBUG (PinVerificationDialog): Network test successful. Status Code: 200, Body: ${response.body}',
        );
      } else {
        print(
          'DEBUG (PinVerificationDialog): Network test failed with status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      print(
        'DEBUG (PinVerificationDialog): Network test failed with exception: ${e.toString()}',
      );
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();

    if (pin.length != 4) {
      setState(() {
        _errorMessage = 'Будь ласка, введіть всі 4 цифри PIN-коду.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _testNetworkConnection(); // Call network test before Supabase invoke

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Ви не авторизовані. Будь ласка, увійдіть.';
          _isLoading = false;
        });
        return;
      }

      print(
        'DEBUG (PinVerificationDialog): Verifying PIN for user: ${currentUser.id}',
      );
      print('DEBUG (PinVerificationDialog): Entered PIN: $pin');

      // Отримуємо cupcop з бази даних для поточного користувача
      final response = await Supabase.instance.client
          .from('profiles')
          .select('cupcop')
          .eq('id', currentUser.id)
          .single();

      final storedCupcop = response['cupcop'] as String?;
      print('DEBUG (PinVerificationDialog): Stored cupcop: $storedCupcop');

      if (storedCupcop == null || storedCupcop.isEmpty) {
        setState(() {
          _errorMessage =
              'PIN-код не встановлено. Будь ласка, встановіть PIN-код.';
          _isLoading = false;
        });
        return;
      }

      // Порівнюємо введений PIN з cupcop
      if (pin == storedCupcop) {
        print('DEBUG (PinVerificationDialog): PIN verified successfully');
        // PIN вірний - закриваємо діалог з успіхом
        Navigator.of(context).pop(true);
      } else {
        print('DEBUG (PinVerificationDialog): PIN verification failed');
        setState(() {
          _errorMessage = 'Невірний PIN-код. Спробуйте ще раз.';
          _isLoading = false;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR (PinVerificationDialog): Exception caught: $e');
      print('ERROR (PinVerificationDialog): Exception type: ${e.runtimeType}');
      print(
        'ERROR (PinVerificationDialog): Exception toString: ${e.toString()}',
      );
      setState(() {
        _errorMessage =
            'Виникла неочікувана помилка при верифікації: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleForgotPin() async {
    try {
      print('DEBUG (PinVerificationDialog): Starting PIN recovery process');

      // Розлогуємо користувача
      await Supabase.instance.client.auth.signOut();
      print('DEBUG (PinVerificationDialog): User signed out successfully');

      // Закриваємо поточний діалог з null (не false!) щоб відрізнити від скасування
      Navigator.of(context).pop(null);

      // Переходимо на сторінку введення номера телефону для відновлення
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const PinRecoveryPhonePage()),
      );

      print('DEBUG (PinVerificationDialog): PIN recovery process completed');
    } catch (e) {
      print('ERROR (PinVerificationDialog): Failed to start PIN recovery: $e');
      print('ERROR (PinVerificationDialog): Error type: ${e.runtimeType}');

      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 40),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () {
                  if (!_isLoading) {
                    Navigator.of(context).pop();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(200),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/x-close.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.color8,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Підтвердьте оголошення',
              style: AppTextStyles.heading2Semibold.copyWith(
                color: Colors.black,
                fontSize: 20,
                height: 1.30,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Text(
                'Введіть PIN-код підтвердження, щоб завершити публікацію',
                textAlign: TextAlign.center,
                style: AppTextStyles.body1Regular.copyWith(
                  color: AppColors.color7,
                  fontSize: 16,
                  height: 1.40,
                  letterSpacing: 0.16,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SixDigitPinInput(
              pinController: _pinController,
              pinFocusNode: _pinFocusNode,
              errorText: _errorMessage,
              onPinCompleted: (pin) => _verifyPin(),
            ),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: List.generate(6, (index) {
            //     return Row(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         Padding(
            //           padding: const EdgeInsets.symmetric(horizontal: 2),
            //           child: _buildPinInputField(_pinControllers[index], _pinFocusNodes[index], index),
            //         ),
            //         if (index == 2)
            //           Text(
            //             '-',
            //             textAlign: TextAlign.center,
            //             style: AppTextStyles.heading2Semibold.copyWith(
            //               color: AppColors.color5,
            //               fontSize: 28,
            //               height: 1.20,
            //             ),
            //           ),
            //       ],
            //     );
            //   }),
            // ),
            // if (_errorMessage != null) ...[
            //   const SizedBox(height: 12),
            //   Text(
            //     _errorMessage!,
            //     style: AppTextStyles.body2Regular.copyWith(color: Colors.red),
            //     textAlign: TextAlign.center,
            //   ),
            // ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: _isLoading ? null : _handleForgotPin,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(Size.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: Text(
                'Забули PIN-код?',
                style: AppTextStyles.body1Medium.copyWith(
                  color: AppColors.primaryColor,
                  decoration: TextDecoration.underline,
                  fontSize: 16,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w500,
                  height: 1.50,
                  letterSpacing: 0.16,
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                    side: const BorderSide(
                      color: AppColors.primaryColor,
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
                        'Підтвердити',
                        style: AppTextStyles.body1Medium.copyWith(
                          color: Colors.white,
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

  // Widget _buildPinInputField(TextEditingController controller, FocusNode focusNode, int index) { // Видалено
  //   return Container(
  //     width: 48,
  //     height: 64,
  //     decoration: BoxDecoration(
  //       color: AppColors.zinc50,
  //       borderRadius: BorderRadius.circular(12),
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
  //         focusNode: focusNode,
  //         keyboardType: TextInputType.number,
  //         textAlign: TextAlign.center,
  //         inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
  //         obscureText: false,
  //         style: AppTextStyles.heading2Semibold.copyWith(color: AppColors.color2, fontSize: 28),
  //         decoration: InputDecoration(
  //           border: InputBorder.none,
  //           contentPadding: EdgeInsets.zero,
  //           isDense: true,
  //           hintText: '0',
  //           hintStyle: AppTextStyles.heading2Semibold.copyWith(color: AppColors.color5, fontSize: 28),
  //         ),
  //         onChanged: (value) {
  //           _onPinChanged(index);
  //         },
  //       ),
  //     ),
  //   );
  // }
}
