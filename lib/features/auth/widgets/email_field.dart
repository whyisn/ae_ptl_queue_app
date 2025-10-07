import 'package:flutter/material.dart';
import '../../../core/utils.dart';

class EmailField extends StatelessWidget {
  final TextEditingController controller;
  const EmailField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username],
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'nama@contoh.com',
      ),
      validator: requiredEmailValidator,
    );
  }
}
