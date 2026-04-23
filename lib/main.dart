import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/employee/employee_pin_screen.dart';
import 'screens/employee/employee_sales_screen.dart';
import 'screens/main_shell.dart';
import 'widgets/web_layout_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only if not already initialized
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (e is FirebaseException && e.code == 'duplicate-app') {
      // Firebase already initialized, continue
    } else {
      rethrow;
    }
  }

  // TEMPORARY: Force sign out on launch (REMOVE AFTER TESTING)
  //await FirebaseAuth.instance.signOut();

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Global error handler for uncaught Firebase errors
  FlutterError.onError = (details) {
    if (details.exception is FirebaseException) {
      final error = details.exception as FirebaseException;
      if (error.code == 'permission-denied') {
        // Sign out the user
        FirebaseAuth.instance.signOut();
      }
    }
    FlutterError.presentError(details);
  };

  runApp(const CannonButcheryApp());
}

class CannonButcheryApp extends StatelessWidget {
  const CannonButcheryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cannon Butchery',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

enum _AppMode { admin, employeePin, employee }

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  _AppMode _mode = _AppMode.admin;

  void _enterEmployeePin() => setState(() => _mode = _AppMode.employeePin);
  void _enterEmployee() => setState(() => _mode = _AppMode.employee);
  void _exitEmployee() => setState(() => _mode = _AppMode.admin);

  @override
  Widget build(BuildContext context) {
    // Employee modes take priority — render independently of auth state
    if (_mode == _AppMode.employeePin) {
      return WebLayoutWrapper(
        child: EmployeePinScreen(
          onSuccess: _enterEmployee,
          onBack: _exitEmployee,
        ),
      );
    }

    if (_mode == _AppMode.employee) {
      return WebLayoutWrapper(
        child: EmployeeSalesScreen(onLock: _enterEmployeePin),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const WebLayoutWrapper(
            child: Scaffold(
              body: Center(child: CircularProgressIndicator(color: kPrimary)),
            ),
          );
        }
        if (snapshot.hasData) {
          return WebLayoutWrapper(
            child: MainShell(onEmployeeAccess: _enterEmployeePin),
          );
        }
        return WebLayoutWrapper(
          child: SignInScreen(onEmployeeAccess: _enterEmployeePin),
        );
      },
    );
  }
}
