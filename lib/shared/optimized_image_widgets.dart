import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/utils/image_load_errors.dart';

/// Widget optimizado para cargar imágenes de red con caché y placeholders
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPlausibleNetworkImageUrl(imageUrl)) {
      return errorWidget ??
          const Icon(Iconsax.info_circle_copy, color: Colors.grey);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ?? const Center(child: AppLoadingIndicator()),
      errorWidget: (context, url, error) =>
          errorWidget ??
          const Icon(Iconsax.info_circle_copy, color: Colors.grey),
      // Optimizaciones de caché
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      maxWidthDiskCache: width != null ? (width! * 3).toInt() : 1000,
      maxHeightDiskCache: height != null ? (height! * 3).toInt() : 1000,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }
}

/// Avatar circular con caché y fallback (evita [NetworkImage] en Samsung).
class SafeCircleAvatar extends StatelessWidget {
  const SafeCircleAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.backgroundColor,
    required this.fallback,
  });

  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final size = radius * 2;
    final bg = backgroundColor ?? Colors.grey.shade200;

    if (!isPlausibleNetworkImageUrl(url)) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: fallback);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 2).toInt(),
          memCacheHeight: (size * 2).toInt(),
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, _) => SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: radius * 0.6,
                height: radius * 0.6,
                child: const AppBrandLoaderCompact(ringSize: 24),
              ),
            ),
          ),
          errorWidget: (_, _, _) => SizedBox(
            width: size,
            height: size,
            child: fallback,
          ),
        ),
      ),
    );
  }
}

/// Widget optimizado para imágenes de assets con caché
class OptimizedAssetImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const OptimizedAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width != null
          ? (width! * MediaQuery.of(context).devicePixelRatio).toInt()
          : null,
      cacheHeight: height != null
          ? (height! * MediaQuery.of(context).devicePixelRatio).toInt()
          : null,
    );
  }
}
