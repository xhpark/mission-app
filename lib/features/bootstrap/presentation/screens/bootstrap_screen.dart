import 'package:flutter/material.dart';

import '../../../../app/constants/app_strings.dart';

class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(AppStrings.bootstrapMessage),
          ],
        ),
      ),
    );
  }
}
