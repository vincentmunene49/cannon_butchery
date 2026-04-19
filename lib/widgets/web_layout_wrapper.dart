import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class WebLayoutWrapper extends StatelessWidget {
  final Widget child;

  const WebLayoutWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 480,
            maxHeight: 900,
          ),
          margin: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                spreadRadius: 0,
              )
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
      ),
    );
  }
}
