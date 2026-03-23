import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_page.dart';
import 'forgot_password_page.dart';
import 'pin_recovery_phone_page.dart';
import '../widgets/six_digit_pin_input.dart'; // Import the new widget

class PinLoginPage extends StatefulWidget {
  final String phoneNumber;

  const PinLoginPage({super.key, required this.phoneNumber});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage; // Додано для відображення помилок

  // late AnimationController _cursorAnimationController; // Видалено

  @override
  void initState() {
    super.initState();
    // _pinController.addListener(() {
    //   setState(() {}); // Перебудовуємо, щоб оновити візуальне відображення PIN-коду та курсору
    // });
    // _pinFocusNode.addListener(() {
    //   setState(() {}); // Перебудовуємо, щоб оновити стан курсору при зміні фокусу
    // });
    // _cursorAnimationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 500),
    // )..repeat(reverse: true);
    // _otpControllers = [ // Ініціалізуємо список контролерів
    //   _otpController1,
    //   _otpController2,
    //   _otpController3,
    //   _otpController4,
    //   _otpController5,
    //   _otpController6,
    // ];
    // Додаємо слухачів до контролерів для автопереходу
    // _otpController1.addListener(() => _onPinChanged(0));
    // _otpController2.addListener(() => _onPinChanged(1));
    // _otpController3.addListener(() => _onPinChanged(2));
    // _otpController4.addListener(() => _onPinChanged(3));
    // _otpController5.addListener(() => _onPinChanged(4));
    // _otpController6.addListener(() => _onPinChanged(5));
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    // _cursorAnimationController.dispose(); // Видалено
    // _otpController1.dispose();
    // _otpController2.dispose();
    // _otpController3.dispose();
    // _otpController4.dispose();
    // _otpController5.dispose();
    // _otpController6.dispose();
    // for (var node in _focusNodes) {
    //   node.dispose();
    // }
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();

    if (pin.length != 6) {
      setState(() {
        _errorMessage =
            'Будь ласка, введіть всі 6 цифр.'; // Встановлюємо помилку
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null; // Очищаємо попередні помилки
    });

    try {
      print('=== START LOGIN ATTEMPT ===');
      print('Phone: ${widget.phoneNumber}');
      print('PIN length: ${pin.length}');

      // Використовуємо phone auth
      final response = await _supabase.auth.signInWithPassword(
        phone: widget.phoneNumber,
        password: pin,
      );

      if (response.session != null) {
        print('Login successful!');
        print('Session user ID: ${response.user?.id}');
        print('Session expires: ${response.session?.expiresAt}');

        // Додатково оновлюємо поле cupcop при логіні на всякий випадок
        try {
          await _supabase
              .from('profiles')
              .update({'cupcop': pin})
              .eq('id', response.user!.id);
          print('DEBUG: Password updated in cupcop field during login');
        } catch (e) {
          print('WARNING: Failed to update cupcop field during login: $e');
          // Не зупиняємо процес логіну, якщо не вдалося оновити cupcop
        }

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        print('Login failed - no session');
        print('Response data: $response');
        setState(() {
          _errorMessage = 'Невірний PIN-код'; // Встановлюємо помилку
        });
      }
      print('=== END LOGIN ATTEMPT ===');
    } on AuthException catch (e) {
      print('=== LOGIN ERROR ===');
      print('Error details: $e');
      print('=== END ERROR ===');
      setState(() {
        _errorMessage = 'Невірний PIN-код'; // Встановлюємо помилку
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleForgotPin() {
    // Перенаправляємо на сторінку відновлення PIN коду
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PinRecoveryPhonePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('=== CURRENT PAGE: PinLoginPage ===');
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
              'Увійти в акаунт',
              style: AppTextStyles.heading2Semibold.copyWith(
                color: AppColors.color2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Введіть ваш PIN-код',
              style: AppTextStyles.body1Regular.copyWith(
                color: AppColors.color8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SixDigitPinInput(
              pinController: _pinController,
              pinFocusNode: _pinFocusNode,
              onPinCompleted: (pin) => _verifyPin(),
              errorText: _errorMessage, // Передаємо повідомлення про помилку
            ),
            // GestureDetector(
            //   onTap: () {
            //     FocusScope.of(context).requestFocus(_pinFocusNode);
            //   },
            //   child: _buildPinDisplay(),
            // ),
            // // Використовуємо Offstage для приховування TextField, але дозволяємо йому отримувати фокус
            // Offstage(
            //   offstage: true,
            //   child: TextField(
            //     controller: _pinController,
            //     focusNode: _pinFocusNode,
            //     keyboardType: TextInputType.number,
            //     maxLength: 6,
            //     onChanged: (value) {
            //       setState(() {}); // For rebuilding to update visual PIN display
            //       if (value.length == 6) {
            //         FocusScope.of(context).unfocus(); // Приховуємо клавіатуру, якщо PIN повний
            //       }
            //     },
            //     decoration: const InputDecoration(
            //       counterText: '',
            //       border: InputBorder.none,
            //     ),
            //     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            //   ),
            // ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44, // Додано явну висоту для кнопки
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200),
                    side: BorderSide(color: AppColors.primaryColor, width: 1),
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
                        'Підтвердити',
                        style: AppTextStyles.body1Medium.copyWith(
                          color: Colors.white,
                          fontSize: 14, // Оновлено розмір шрифту
                          fontWeight:
                              FontWeight.w600, // Оновлено товщину шрифту
                          height: 1.40, // Оновлено висоту рядка
                          letterSpacing: 0.14, // Оновлено інтервал між літерами
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _handleForgotPin,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(Size.zero),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: Text(
                'Забули ПІН-код?',
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

  // Widget _buildPinDisplay() { // Видалено
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.center,
  //     children: List.generate(6, (index) {
  //       bool isFilled = index < _pinController.text.length;
  //       bool isActive = index == _pinController.text.length && _pinFocusNode.hasFocus;
  //       String char = isFilled ? _pinController.text[index] : '';
  //
  //       return AnimatedBuilder(
  //         animation: _cursorAnimationController,
  //         builder: (context, child) {
  //           return Container(
  //             width: 48,
  //             height: 48,
  //             margin: EdgeInsets.symmetric(horizontal: index == 2 ? 10 : 4), // Додано margin для тире
  //             decoration: BoxDecoration(
  //               color: AppColors.zinc50,
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(
  //                 color: isActive && _cursorAnimationController.value > 0.5
  //                     ? AppColors.primaryColor
  //                     : AppColors.zinc200,
  //                 width: 1,
  //               ),
  //               boxShadow: const [
  //                 BoxShadow(
  //                   color: Color.fromRGBO(16, 24, 40, 0.05),
  //                   offset: Offset(0, 1),
  //                   blurRadius: 2,
  //                 ),
  //               ],
  //             ),
  //             child: Center(
  //               child: Stack(
  //                 alignment: Alignment.center,
  //                 children: [
  //                   Text(
  //                     char,
  //                     style: AppTextStyles.body1Medium.copyWith(color: AppColors.color2),
  //                   ),
  //                   if (isActive && _cursorAnimationController.value > 0.5 && char.isEmpty)
  //                     Text(
  //                       '|',
  //                       style: AppTextStyles.body1Medium.copyWith(color: AppColors.color2),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     }),
  //   );
  // }
}
