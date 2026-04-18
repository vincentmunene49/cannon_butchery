import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

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

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimary),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainShell();
        }
        return const SignInScreen();
      },
    );
  }
}
