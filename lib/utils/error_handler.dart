import 'package:flutter/material.dart';
import '../services/auth_service.dart';

void showPermissionDeniedDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Access Denied'),
      content: const Text(
        'You do not have permission to access this data. Please sign in with an authorized account.',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await AuthService.signOut();
          },
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
}

bool handleFirestoreError(dynamic error, BuildContext context) {
  if (error.toString().contains('permission-denied')) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showPermissionDeniedDialog(context);
    });
    return true;
  }
  return false;
}
