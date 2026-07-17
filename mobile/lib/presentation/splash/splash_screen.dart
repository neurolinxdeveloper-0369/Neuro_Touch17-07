import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth.controller.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();

    // Navigate after auth check
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      final authState = ref.read(authControllerProvider);
      if (authState.isAuthenticated) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.darkBg,
        child: Stack(
          children: [
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo mark
                        ScaleTransition(
                          scale: _scaleAnim,
                          child: Container(
                            width: screenSize.width * 0.22,
                            height: screenSize.width * 0.22,
                            decoration: BoxDecoration(
                              color: AppColors.primaryCard,
                              borderRadius: BorderRadius.circular(
                                  screenSize.width * 0.055),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.home_rounded,
                                color: Colors.white,
                                size: screenSize.width * 0.11,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: screenSize.height * 0.03),

                        // App name
                        const Text(
                          'Neuro Touch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            fontFamily: 'Inter',
                          ),
                        ),

                        SizedBox(height: screenSize.height * 0.008),

                        const Text(
                          'Smart Home, Reimagined',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                            fontFamily: 'Inter',
                          ),
                        ),

                        SizedBox(height: screenSize.height * 0.06),

                        // Loading indicator
                        SizedBox(
                          width: screenSize.width * 0.08,
                          height: screenSize.width * 0.08,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom version
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (context, child) => FadeTransition(
                  opacity: _fadeAnim,
                  child: const Text(
                    'v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
