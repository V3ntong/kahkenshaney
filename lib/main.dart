import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'mainpage.dart';
import 'pages/choose_action_page.dart';
import 'pages/report_lost_page.dart';
import 'pages/submit_found_page.dart';
import 'providers/profile_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/split_flap_splash.dart';

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
  );
  debugPrint('App Check activated successfully');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const AmongApp());
}

class AmongApp extends StatelessWidget {
  const AmongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show native splash while Firebase initializes
          return MaterialApp(
            title: 'KAH KEN SHA NEY',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const _NativeSplashPlaceholder(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            title: 'KAH KEN SHA NEY',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const _FirebaseErrorScreen(),
          );
        }

        // Firebase initialized - show split-flap splash screen then MainPage
        return ChangeNotifierProvider(
          create: (_) => ProfileProvider(),
          child: MaterialApp(
            title: 'KAH KEN SHA NEY',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const _SplashWrapper(),
            routes: {
              '/choose-action': (_) => const ChooseActionPage(),
              '/report-lost': (_) => const ReportLostPage(),
              '/submit-found': (_) => const SubmitFoundPage(),
            },
          ),
        );
      },
    );
  }
}

class _SplashWrapper extends StatefulWidget {
  const _SplashWrapper();

  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper> {
  bool _showSplash = true;

  void _onSplashComplete() {
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplitFlapSplashScreen(
        initializationFuture: () async {
          // Any additional initialization can go here
          await Future.delayed(const Duration(milliseconds: 100));
        },
        onComplete: _onSplashComplete,
      );
    }

    return const MainPage();
  }
}

/// Placeholder shown during Firebase initialization (before split-flap splash)
class _NativeSplashPlaceholder extends StatelessWidget {
  const _NativeSplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'KAH KEN SHA NEY',
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 48,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseErrorScreen extends StatelessWidget {
  const _FirebaseErrorScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFDC2626),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Connection Error',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unable to connect to Firebase services. '
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    // Restart the app by recreating the widget tree
                    // In practice, this would need a proper app restart
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AmongApp()),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
