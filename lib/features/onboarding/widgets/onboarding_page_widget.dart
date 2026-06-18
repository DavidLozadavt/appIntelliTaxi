import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/onboarding/data/onboarding_page_model.dart';

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingPageModel page;
  final bool isLastPage;
  final double bottomControlsHeight;

  const OnboardingPageWidget({
    super.key,
    required this.page,
    this.isLastPage = false,
    this.bottomControlsHeight = 150,
  });

  static const _titleStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 24,
    height: 1.15,
  );

  static const _descriptionStyle = TextStyle(
    color: Color(0xFFA3ADBF),
    fontSize: 13,
    height: 1.35,
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBrandLogoOnly = page.imagePath.contains('logoTaxbel.webp');

    return Container(
      color: const Color(0xFF17130D),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          topInset + 12,
          24,
          bottomControlsHeight,
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (page.showBrandLogo) ...[
                    _BrandLogoImage(isDark: isDark),
                    const SizedBox(height: 20),
                    _TitleSection(page: page),
                    const SizedBox(height: 10),
                    Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style: _descriptionStyle,
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Image.asset(
                        page.imagePath,
                        fit: BoxFit.contain,
                        alignment: page.imageAlignment,
                      ),
                    ),
                  ] else if (isBrandLogoOnly) ...[
                    _BrandLogoImage(isDark: isDark),
                    const SizedBox(height: 28),
                    _TitleSection(page: page),
                    const SizedBox(height: 10),
                    Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style: _descriptionStyle,
                    ),
                  ] else ...[
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Image.asset(
                          page.imagePath,
                          fit: BoxFit.contain,
                          alignment: page.imageAlignment,
                        ),
                      ),
                    ),
                    _TitleSection(page: page),
                    const SizedBox(height: 10),
                    Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style: _descriptionStyle,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.page});

  final OnboardingPageModel page;

  @override
  Widget build(BuildContext context) {
    if (page.highlightedText != null) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: OnboardingPageWidget._titleStyle,
          children: [
            TextSpan(text: '${page.title}\n'),
            TextSpan(
              text: page.highlightedText!,
              style: const TextStyle(color: AppColors.accent),
            ),
          ],
        ),
      );
    }

    return Text(
      page.title,
      textAlign: TextAlign.center,
      style: OnboardingPageWidget._titleStyle,
    );
  }
}

class _BrandLogoImage extends StatelessWidget {
  const _BrandLogoImage({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: !isDark
          ? const ColorFilter.mode(AppColors.brandWine, BlendMode.modulate)
          : const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
      child: Image.asset(
        'assets/images/logoTaxbel.webp',
        height: 88,
        fit: BoxFit.contain,
      ),
    );
  }
}
