import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth.controller.dart';

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
      backgroundColor: const Color(0xFF010817),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF010817), Color(0xFF45484D), Color(0xFF0D1438)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: -screenSize.width * 0.3,
              right: -screenSize.width * 0.2,
              child: Container(
                width: screenSize.width * 0.7,
                height: screenSize.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4C6FFF).withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -screenSize.width * 0.2,
              left: -screenSize.width * 0.15,
              child: Container(
                width: screenSize.width * 0.6,
                height: screenSize.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C5CE7).withOpacity(0.06),
                ),
              ),
            ),

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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4C6FFF), Color(0xFF6C5CE7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                  screenSize.width * 0.055),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4C6FFF).withOpacity(0.5),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
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
                        Text(
                          'Neuro Touch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenSize.width * 0.08,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            fontFamily: 'Inter',
                          ),
                        ),

                        SizedBox(height: screenSize.height * 0.008),

                        Text(
                          'Smart Home, Reimagined',
                          style: TextStyle(
                            color: const Color(0xFFB2BEC3),
                            fontSize: screenSize.width * 0.038,
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
                            color: Color(0xFF4C6FFF),
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
                  child: Text(
                    'v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFB2BEC3).withOpacity(0.4),
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
