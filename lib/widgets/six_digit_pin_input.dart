import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zeno/theme/app_colors.dart';
import 'package:zeno/theme/app_text_styles.dart';
import 'package:zeno/services/sms_autofill_service.dart';

class SixDigitPinInput extends StatefulWidget {
  final TextEditingController pinController;
  final FocusNode pinFocusNode;
  final Function(String)? onPinCompleted;
  final String? errorText;
  final int length;

  const SixDigitPinInput({
    super.key,
    required this.pinController,
    required this.pinFocusNode,
    this.onPinCompleted,
    this.errorText,
    this.length = 6,
  });

  @override
  State<SixDigitPinInput> createState() => _SixDigitPinInputState();
}

class _SixDigitPinInputState extends State<SixDigitPinInput>
    with TickerProviderStateMixin {
  late AnimationController _cursorAnimationController;
  final SmsAutofillService _smsService = SmsAutofillService();
  StreamSubscription<String>? _smsSubscription;

  @override
  void initState() {
    super.initState();
    widget.pinController.addListener(_onPinChanged);
    widget.pinFocusNode.addListener(_onFocusChanged);
    _cursorAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _initializeSmsAutofill();
  }

  void _initializeSmsAutofill() async {
    try {
      await _smsService.initialize();
      print('SMS автозаповнення ініціалізовано для SixDigitPinInput');
    } catch (e) {
      print('Помилка ініціалізації SMS автозаповнення: $e');
    }
  }

  @override
  void dispose() {
    widget.pinController.removeListener(_onPinChanged);
    widget.pinFocusNode.removeListener(_onFocusChanged);
    widget.pinController.dispose(); // Dispose here as it's passed in
    widget.pinFocusNode.dispose(); // Dispose here as it's passed in
    _cursorAnimationController.dispose();
    _smsSubscription?.cancel();
    _smsService.dispose();
    super.dispose();
  }

  void _onPinChanged() {
    setState(() {});
    if (widget.pinController.text.length == widget.length) {
      widget.pinFocusNode.unfocus();
      widget.onPinCompleted?.call(widget.pinController.text);
    }
  }

  @override
  void didUpdateWidget(SixDigitPinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Очищаємо поле при появі помилки
    if (oldWidget.errorText == null &&
        widget.errorText != null &&
        widget.errorText!.isNotEmpty) {
      widget.pinController.clear();
    }
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(widget.pinFocusNode);
          },
          child: _buildPinDisplay(),
        ),
        Offstage(
          offstage: true,
          child: TextField(
            controller: widget.pinController,
            focusNode: widget.pinFocusNode,
            keyboardType: TextInputType.number,
            maxLength: widget.length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            enableSuggestions: true,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
          ),
        ),
        if (widget.errorText != null && widget.errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              widget.errorText!,
              style: AppTextStyles.body2Regular.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        bool isFilled = index < widget.pinController.text.length;
        bool isActive =
            index == widget.pinController.text.length &&
            widget.pinFocusNode.hasFocus;
        String char = isFilled ? widget.pinController.text[index] : '';

        return AnimatedBuilder(
          animation: _cursorAnimationController,
          builder: (context, child) {
            return Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.zinc50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      widget.errorText != null && widget.errorText!.isNotEmpty
                      ? Colors
                            .red // Red border if there's an error
                      : (isActive && _cursorAnimationController.value > 0.5
                            ? AppColors.primaryColor
                            : AppColors.zinc200),
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
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      char,
                      style: AppTextStyles.body1Medium.copyWith(
                        color: AppColors.color2,
                      ),
                    ),
                    if (isActive &&
                        _cursorAnimationController.value > 0.5 &&
                        char.isEmpty)
                      Text(
                        '|',
                        style: AppTextStyles.body1Medium.copyWith(
                          color: AppColors.color2,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
