import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/app_logo.dart';
import '../widgets/chatbot.dart';
import 'auth/change_password_screen.dart';
import 'auth/login.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  bool get _ready => _auth.currentUser != null;

  late final AnimationController _welcomeFade;
  bool _welcomeVisible = true;
  int _currentTab = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _welcomeFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _guardRoute();
      _listenUnread();
      _initNotifications();
    });
  }

  @override
  void dispose() {
    _welcomeFade.dispose();
    _unreadSub?.cancel();
    super.dispose();
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _unreadSub;

  void _listenUnread() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _unreadSub = FirebaseFirestore.instance
        .collection('chats')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      final count = (data?['unreadByUserCount'] as num?)?.toInt() ?? 0;
      setState(() => _unreadCount = count);
    }, onError: (_) {});
  }

  void _initNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    NotificationService().initialize(userId: uid);
  }

  void _dismissWelcome() {
    if (!_welcomeVisible) return;
    _welcomeFade.reverse().whenComplete(() {
      if (mounted) setState(() => _welcomeVisible = false);
    });
  }

  Future<void> _guardRoute() async {
    if (_auth.currentUser == null) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      FadeThroughRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToChangePassword() {
    final email = _auth.currentUser?.email ?? '';
    Navigator.push(
      context,
      FadeSlideRoute(
        builder: (_) => ChangePasswordScreen(
          email: email,
          authService: widget.authService,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      FadeThroughRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _auth.currentUser!;
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'there';
    final email = user.email ?? '';
    final photoUrl = user.photoURL;

    return Stack(
      children: [
        HomePage(
          userName: displayName,
          userEmail: email,
          photoUrl: photoUrl,
          ownerUid: _auth.currentUser?.uid,
          onChangePassword: _goToChangePassword,
          onSignOut: _signOut,
          onTabChanged: (index) => setState(() => _currentTab = index),
          unreadCount: _unreadCount,
        ),
        if (_currentTab != 4) const ChatbotButton(),
        if (_welcomeVisible) _buildWelcomeOverlay(displayName),
      ],
    );
  }

  Widget _buildWelcomeOverlay(String displayName) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _welcomeFade,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismissWelcome,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.4),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Hero(
                      tag: 'app-logo',
                      child: AppLogo(size: 64),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome, $displayName!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap anywhere to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
