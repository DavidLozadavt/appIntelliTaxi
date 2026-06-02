import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/onboarding/data/onboarding_page_model.dart';
import 'package:intellitaxi/features/onboarding/widgets/onboarding_page_widget.dart';
import 'package:intellitaxi/features/onboarding/services/onboarding_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _nextPage() {
    if (_currentPage < onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  double _bottomControlsHeight(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const baseHeight = 116.0;
    const skipLinkHeight = 32.0;
    final hasSkipLink = _currentPage < onboardingPages.length - 1;
    return baseHeight + bottomInset + (hasSkipLink ? skipLinkHeight : 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomControlsHeight = _bottomControlsHeight(context);

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: onboardingPages.length,
            itemBuilder: (context, index) {
              return OnboardingPageWidget(
                page: onboardingPages[index],
                isLastPage: index == onboardingPages.length - 1,
                bottomControlsHeight: bottomControlsHeight,
              );
            },
          ),

          if (_currentPage < onboardingPages.length - 1)
            Positioned(
              top: 0,
              right: 12,
              child: SafeArea(
                child: TextButton(
                  onPressed: _skipOnboarding,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Saltar',
                    style: TextStyle(
                      color: Color(0xFFADB4C2),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        onboardingPages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == index ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.accent
                                : const Color(0xFF384A6A),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: const Color(0xFF111111),
                          elevation: 6,
                          shadowColor: AppColors.accent.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == onboardingPages.length - 1
                                  ? 'Comenzar'
                                  : 'Siguiente',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _currentPage == onboardingPages.length - 1
                                  ? Iconsax.tick_circle_copy
                                  : Iconsax.arrow_right_3_copy,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_currentPage < onboardingPages.length - 1) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _completeOnboarding,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Omitir introducción',
                          style: TextStyle(
                            color: Color(0xFF8F98AA),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
