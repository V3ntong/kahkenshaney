import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/auth/signup.dart';
import 'theme/app_theme.dart';
import 'utils/page_transitions.dart';
import 'widgets/app_logo.dart';
import 'widgets/text_animations.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const AppLogo(size: 32)),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Hero(tag: 'app-logo', child: AppLogo(size: 80)),
                      const SizedBox(height: 32),

                      // Headline with blur-to-focus animation (Bebas Neue)
                      BlurRevealText(
                        text: 'KAH KEN SHA NEY',
                        duration: const Duration(milliseconds: 1700),
                        maxBlur: 14,
                        slideOffset: 24,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 36,
                          color: AppColors.textPrimary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle with typewriter animation (Lobster Two)
                      TypewriterText(
                        text:
                            "We find what your memory can't. For people who lose "
                            'things more often than they change their socks.',
                        textAlign: TextAlign.center,
                        speed: kTypewriterSpeedSlow,
                        delay: const Duration(milliseconds: 300),
                        showCursor: false,
                        style: GoogleFonts.lobsterTwo(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Get Started button — redirects to Sign Up
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              FadeSlideRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: AppColors.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Footer
          const _Footer(),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Text(
        '\u00a9 ${DateTime.now().year} KAH KEN SHA NEY. All rights reserved.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
    );
  }
}
