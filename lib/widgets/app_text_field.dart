import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.autovalidateMode,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.helperText,
    this.helperStyle,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final AutovalidateMode? autovalidateMode;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;
  final int? maxLines;
  final int? minLines;
  final String? helperText;
  final TextStyle? helperStyle;

  void _handleSubmit(BuildContext context, String value) {
    if (onFieldSubmitted != null) {
      onFieldSubmitted!(value);
      return;
    }
    if (nextFocusNode != null) {
      FocusScope.of(context).requestFocus(nextFocusNode);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      readOnly: readOnly,
      autovalidateMode: autovalidateMode,
      inputFormatters: inputFormatters,
      onFieldSubmitted: (value) => _handleSubmit(context, value),
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      cursorColor: theme.colorScheme.primary,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: theme.textTheme.bodyLarge?.fontSize,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: helperStyle,
      ),
    );
  }
}
