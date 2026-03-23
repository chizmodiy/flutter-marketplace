import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/six_digit_pin_input.dart'; // Import the new widget

class PinResetPage extends StatefulWidget {
  const PinResetPage({super.key});

  @override
  State<PinResetPage> createState() => _PinResetPageState();
}

class _PinResetPageState extends State<PinResetPage> {
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmNewPinController =
      TextEditingController();

  final FocusNode _newPinFocusNode = FocusNode(); // Added for new PIN
  final FocusNode _confirmNewPinFocusNode =
      FocusNode(); // Added for confirmation PIN

  // bool _obscureNewPin = true; // Видалено
  // bool _obscureConfirmNewPin = true; // Видалено

  bool _isLoading = false;
  String? _errorMessage;
  String? _newPinError;
  String? _confirmNewPinError;
  bool _isButtonEnabled = false;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG (PinResetPage): initState called');
    _newPinController.addListener(_validateFields);
    _confirmNewPinController.addListener(_validateFields);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print(
      'DEBUG (PinResetPage): Current route: ${ModalRoute.of(context)?.settings.name}',
    );
  }

  @override
  void dispose() {
    _newPinController.removeListener(_validateFields);
    _confirmNewPinController.removeListener(_validateFields);
    _newPinController.dispose();
    _confirmNewPinController.dispose();
    _newPinFocusNode.dispose(); // Dispose new focus node
    _confirmNewPinFocusNode.dispose(); // Dispose confirm focus node
    super.dispose();
  }

  void _validateFields() {
    setState(() {
      _newPinError = null;
      _confirmNewPinError = null;

      final newPin = _newPinController.text;
      final confirmNewPin = _confirmNewPinController.text;

      bool isValid = true;

      if (newPin.length != 6) {
        _newPinError = 'PIN-код повинен містити 6 цифр.';
        isValid = false;
      }

      if (confirmNewPin.length != 6) {
        _confirmNewPinError = 'Підтвердження PIN-коду повинно містити 6 цифр.';
        isValid = false;
      }

      if (newPin != confirmNewPin &&
          newPin.length == 6 &&
          confirmNewPin.length == 6) {
        _confirmNewPinError = 'PIN-коди не співпадають.';
        isValid = false;
      }

      _isButtonEnabled =
          isValid && newPin.isNotEmpty && confirmNewPin.isNotEmpty;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handlePinReset() async {
    // Renamed method
    setState(() {
      _showValidationErrors = true;
    });
    _validateFields();

    if (!_isButtonEnabled) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newPin = _newPinController.text;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.phone == null) {
        _showSnackBar(
          'Користувач не авторизований або номер телефону не знайдено.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPin),
      );

      // Додатково зберігаємо пароль в поле cupcop
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'cupcop': newPin})
            .eq('id', user.id);
        print('DEBUG: Password saved to cupcop field');
      } catch (e) {
        print('WARNING: Failed to save password to cupcop field: $e');
        // Не зупиняємо процес, якщо не вдалося зберегти в cupcop
      }

      _showSnackBar('PIN-код успішно відновлено!');
      if (mounted) {
        Navigator.of(context).pop(true); // Pop with true to indicate success
      }
    } catch (e) {
      _showSnackBar(
        'Помилка відновлення PIN-коду: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () =>
              Navigator.of(context).pop(false), // Pop with false on back press
          child: const Icon(
            Icons.arrow_back,
            color: Color(0xFF27272A),
            size: 24,
          ),
        ),
        title: const Text(
          'Відновлення PIN-коду', // Updated title
          style: TextStyle(
            color: Color(0xFF161817),
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            height: 1.20,
          ),
        ),
        centerTitle: false,
        leadingWidth: 50,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 80),
                    // Input field for new PIN
                    Text(
                      'Новий PIN-код',
                      style: const TextStyle(
                        color: Color(0xFF52525B),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.40,
                        letterSpacing: 0.14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SixDigitPinInput(
                      pinController: _newPinController,
                      pinFocusNode: _newPinFocusNode,
                      errorText: _showValidationErrors ? _newPinError : null,
                    ),
                    // _buildPinInputField(
                    //   context: context,
                    //   title: 'Новий PIN-код',
                    //   controller: _newPinController,
                    //   obscureText: _obscureNewPin,
                    //   onToggleObscure: () {
                    //     setState(() {
                    //       _obscureNewPin = !_obscureNewPin;
                    //     });
                    //   },
                    //   errorText: _showValidationErrors ? _newPinError : null,
                    // ),
                    const SizedBox(height: 16),
                    // Input field for confirm new PIN
                    Text(
                      'Підтвердіть PIN-код',
                      style: const TextStyle(
                        color: Color(0xFF52525B),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.40,
                        letterSpacing: 0.14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SixDigitPinInput(
                      pinController: _confirmNewPinController,
                      pinFocusNode: _confirmNewPinFocusNode,
                      errorText: _showValidationErrors
                          ? _confirmNewPinError
                          : null,
                    ),
                    // _buildPinInputField(
                    //   context: context,
                    //   title: 'Підтвердіть PIN-код',
                    //   controller: _confirmNewPinController,
                    //   obscureText: _obscureConfirmNewPin,
                    //   onToggleObscure: () {
                    //     setState(() {
                    //       _obscureConfirmNewPin = !_obscureConfirmNewPin;
                    //     });
                    //   },
                    //   errorText: _showValidationErrors ? _confirmNewPinError : null,
                    // ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          // Buttons section (now sticky at the bottom)
          Padding(
            padding: const EdgeInsets.only(left: 13, right: 13, bottom: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isButtonEnabled && !_isLoading
                        ? _handlePinReset
                        : null, // Renamed handler
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isButtonEnabled
                          ? AppColors.primaryColor
                          : AppColors.primaryColor.withOpacity(0.5),
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(200),
                        side: BorderSide(
                          color: _isButtonEnabled
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
                        : const Text(
                            'Підтвердити',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              height: 1.40,
                              letterSpacing: 0.14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      _newPinController.clear();
                      _confirmNewPinController
                          .clear(); // Clear confirm field as well
                      Navigator.of(
                        context,
                      ).pop(false); // Pop with false on cancel
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                        color: Color(0xFFE4E4E7),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(200),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      elevation: 0,
                      shadowColor: const Color.fromRGBO(16, 24, 40, 0.05),
                    ),
                    child: const Text(
                      'Скасувати',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'Inter',
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
        ],
      ),
    );
  }

  // Widget _buildPinInputField({ // Видалено
  //   required BuildContext context,
  //   required String title,
  //   required TextEditingController controller,
  //   required bool obscureText,
  //   required VoidCallback onToggleObscure,
  //   String? errorText,
  // }) {
  //   return Column(
  //     mainAxisSize: MainAxisSize.min,
  //     mainAxisAlignment: MainAxisAlignment.center,
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         title,
  //         style: const TextStyle(
  //           color: Color(0xFF52525B),
  //           fontSize: 14,
  //           fontFamily: 'Inter',
  //           fontWeight: FontWeight.w500,
  //           height: 1.40,
  //           letterSpacing: 0.14,
  //         ),
  //       ),
  //       const SizedBox(height: 6),
  //       Container(
  //         width: double.infinity,
  //         height: 44,
  //         padding: const EdgeInsets.symmetric(horizontal: 16),
  //         clipBehavior: Clip.antiAlias,
  //         decoration: ShapeDecoration(
  //           color: const Color(0xFFFAFAFA),
  //           shape: RoundedRectangleBorder(
  //             side: BorderSide(
  //               width: 1,
  //               color: _showValidationErrors && errorText != null ? const Color(0xFFD33E19) : const Color(0xFFE4E4E7),
  //             ),
  //             borderRadius: BorderRadius.circular(200),
  //           ),
  //           shadows: const [
  //             BoxShadow(
  //               color: Color.fromRGBO(16, 24, 40, 0.05),
  //               offset: Offset(0, 1),
  //               blurRadius: 2,
  //               spreadRadius: 0,
  //             )
  //           ],
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           mainAxisAlignment: MainAxisAlignment.start,
  //           crossAxisAlignment: CrossAxisAlignment.center,
  //           children: [
  //             Expanded(
  //               child: TextField(
  //                 controller: controller,
  //                 obscureText: obscureText,
  //                 keyboardType: TextInputType.number,
  //                 inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
  //                 style: const TextStyle(
  //                   color: Color(0xFF161817),
  //                   fontSize: 16,
  //                   fontFamily: 'Inter',
  //                   fontWeight: FontWeight.w400,
  //                   height: 1.50,
  //                   letterSpacing: 0.16,
  //                 ),
  //                 decoration: const InputDecoration(
  //                   border: InputBorder.none,
  //                   isDense: true,
  //                   contentPadding: EdgeInsets.zero,
  //                   hintText: '••••••',
  //                   hintStyle: TextStyle(
  //                     color: Color(0xFFA1A1AA),
  //                     fontSize: 16,
  //                     fontFamily: 'Inter',
  //                     fontWeight: FontWeight.w400,
  //                     height: 1.50,
  //                     letterSpacing: 0.16,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //             GestureDetector(
  //               onTap: onToggleObscure,
  //               child: SvgPicture.asset(
  //                 obscureText ? 'assets/icons/eye-close.svg' : 'assets/icons/Eye-open.svg',
  //                 width: 24,
  //                 height: 24,
  //                 colorFilter: const ColorFilter.mode(Color(0xFF52525B), BlendMode.srcIn),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       if (_showValidationErrors && errorText != null) ...[
  //         const SizedBox(height: 6),
  //         Text(
  //           errorText,
  //           style: const TextStyle(
  //             color: Color(0xFFD33E19),
  //             fontSize: 14,
  //             fontFamily: 'Inter',
  //             fontWeight: FontWeight.w400,
  //             height: 1.40,
  //             letterSpacing: 0.14,
  //           ),
  //         ),
  //       ],
  //     ],
  //   );
  // }
}
