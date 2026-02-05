import 'package:flutter/material.dart';

/// ListView optimizado para mejor rendimiento
/// Incluye configuraciones que reducen overhead de memoria y CPU
class OptimizedListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final ScrollPhysics? physics;
  final Widget? emptyWidget;
  final bool shrinkWrap;
  final ScrollController? controller;

  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.padding,
    this.itemExtent,
    this.physics,
    this.emptyWidget,
    this.shrinkWrap = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: items.length,
      itemExtent: itemExtent,
      shrinkWrap: shrinkWrap,
      physics: physics,
      // Optimizaciones de rendimiento
      addAutomaticKeepAlives: false, // Ahorra memoria
      addRepaintBoundaries: true, // Mejora rendering
      cacheExtent: 500, // Pre-renderiza items cercanos
      itemBuilder: (context, index) {
        // RepaintBoundary aísla el repintado de cada item
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }
}

/// GridView optimizado para mejor rendimiento
class OptimizedGridView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final ScrollPhysics? physics;
  final Widget? emptyWidget;
  final bool shrinkWrap;

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.padding,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 1,
    this.physics,
    this.emptyWidget,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      shrinkWrap: shrinkWrap,
      physics: physics,
      // Optimizaciones de rendimiento
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }
}

/// PageView optimizado
class OptimizedPageView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final bool allowImplicitScrolling;

  const OptimizedPageView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.onPageChanged,
    this.allowImplicitScrolling = false,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: itemCount,
      onPageChanged: onPageChanged,
      allowImplicitScrolling: allowImplicitScrolling,
      // Optimizaciones
      padEnds: true,
      itemBuilder: (context, index) {
        return RepaintBoundary(child: itemBuilder(context, index));
      },
    );
  }
}

/// Separator optimizado para listas (usa const)
class OptimizedDivider extends StatelessWidget {
  final double height;
  final double indent;
  final double endIndent;
  final Color? color;

  const OptimizedDivider({
    super.key,
    this.height = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      indent: indent,
      endIndent: endIndent,
      color: color,
    );
  }
}
