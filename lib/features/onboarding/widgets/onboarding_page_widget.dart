import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/onboarding/data/onboarding_page_model.dart';

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingPageModel page;
  final bool isLastPage;

  const OnboardingPageWidget({
    super.key,
    required this.page,
    this.isLastPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBrandLogo = page.imagePath.contains('logoTaxbel.webp');

    return Container(
      color: const Color(0xFF17130D),
      child: Column(
        children: [
          Expanded(
            flex: 47,
            child: Padding(
              padding: EdgeInsets.only(top: topInset + 20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF17130D)),
                  Align(
                    alignment: const Alignment(0, 0.34),
                    child: FractionallySizedBox(
                      widthFactor: 0.99,
                      heightFactor: 0.95,
                      child: ColorFiltered(
                        colorFilter: (!isDark && isBrandLogo)
                            ? const ColorFilter.mode(
                                AppColors.brandWine,
                                BlendMode.modulate,
                              )
                            : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.srcOver,
                              ),
                        child: Image.asset(
                          page.imagePath,
                          fit: BoxFit.contain,
                          alignment: page.imageAlignment,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 56,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF17130D),
              padding: const EdgeInsets.fromLTRB(28, 52, 28, 0),
              child: Column(
                children: [
                  if (page.highlightedText != null)
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          height: 1.18,
                        ),
                        children: [
                          TextSpan(text: '${page.title}\n'),
                          TextSpan(
                            text: page.highlightedText!,
                            style: const TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        height: 1.18,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFA3ADBF),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
