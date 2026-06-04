import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/providers/solicitudes_pendientes_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/widgets/solicitud_servicio_card.dart';

/// Pestañas compactas bajo el chip «En línea».
class ConductorMapServiciosTabs {
  ConductorMapServiciosTabs._();

  static bool pantallaCompacta(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 680;

  static double tabBarHeight(BuildContext context) =>
      pantallaCompacta(context) ? 30 : 34;

  static Widget tabBar({
    required BuildContext context,
    required TabController controller,
    required int llegando,
    required int enEspera,
  }) {
    final h = tabBarHeight(context);
    final compact = pantallaCompacta(context);
    return SizedBox(
      height: h,
      child: TabBar(
        controller: controller,
        tabAlignment: TabAlignment.fill,
        labelColor: AppColors.accent,
        unselectedLabelColor: Colors.grey,
        labelStyle: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: AppColors.accent,
        indicatorWeight: 2.5,
        dividerHeight: 0,
        tabs: [
          _tab('Llegando', llegando, height: h, highlight: llegando > 0),
          _tab('En espera', enEspera, height: h, highlight: enEspera > 0),
        ],
      ),
    );
  }

  static Tab _tab(
    String text,
    int count, {
    required double height,
    bool highlight = false,
  }) {
    return Tab(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: highlight ? AppColors.accent : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Altura total del bloque chip + tabs (para posicionar el panel debajo).
  static double headerBlockHeight(
    BuildContext context,
    ConductorHomeProvider provider, {
    required double chipAltura,
    bool avisoEsperaEnLlegando = false,
  }) {
    final compact = pantallaCompacta(context);
    var h = 12.0;
    h += chipAltura;
    h += tabBarHeight(context);
    if (avisoEsperaEnLlegando) {
      h += 44;
    }
    h += compact ? 4.0 : 6.0;
    return h;
  }

  /// Si debe mostrarse el bloque bajo las pestañas.
  static bool shouldShowPanel({
    required TabController controller,
    required ConductorHomeProvider home,
    required SolicitudesPendientesProvider pendientes,
  }) {
    if (controller.index == 0) {
      return home.solicitudesOrdenadas.isNotEmpty ||
          home.totalSolicitudesEnEspera > 0;
    }
    return pendientes.total > 0 ||
        pendientes.cargando ||
        pendientes.error != null;
  }

  static bool mostrarAvisoEnEsperaEnLlegando({
    required TabController controller,
    required ConductorHomeProvider home,
  }) =>
      controller.index == 0 &&
      home.solicitudesOrdenadas.isEmpty &&
      home.totalSolicitudesEnEspera > 0;

  /// Cuántas tarjetas deben verse sin hacer scroll (5 en pantallas bajas, 6 en el resto).
  static int visibleCardsTarget(BuildContext context) =>
      pantallaCompacta(context) ? 5 : 6;

  static double compactCardItemExtent(BuildContext context) =>
      pantallaCompacta(context) ? 118.0 : 124.0;

  static const double _listGap = 8.0;
  static const double _listPadding = 12.0;
  static const double _refreshBarHeight = 34.0;

  /// Evita `ArgumentError` de [num.clamp] cuando min > max (pantallas bajas).
  static double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
  }

  static double _listPanelHeight(
    BuildContext context, {
    required bool conBarraRefresh,
  }) {
    final n = visibleCardsTarget(context);
    final cardH = compactCardItemExtent(context);
    final refreshH = conBarraRefresh ? _refreshBarHeight : 0.0;
    final minH = cardH * 2 + _listGap + _listPadding + refreshH;
    final desired =
        cardH * n + _listGap * (n - 1) + _listPadding + refreshH;

    final screenH = MediaQuery.sizeOf(context).height;
    final topPad = MediaQuery.paddingOf(context).top;
    // Espacio para chip+tabs, dock inferior y FABs.
    const reservedInferior = 188.0;
    const reservedSuperior = 118.0;
    final available = screenH - topPad - reservedSuperior - reservedInferior;
    final maxH = _safeClamp(available, minH, screenH * 0.62);

    return _safeClamp(desired, minH, maxH);
  }

  static Widget _panelShell({
    required BuildContext context,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _listPanelHeight(context, conBarraRefresh: false),
        child: child,
      ),
    );
  }

  static Widget panel({
    required BuildContext context,
    required TabController controller,
    required ConductorHomeProvider home,
    required SolicitudesPendientesProvider pendientes,
    required void Function(String id) onAceptarLlegando,
    required void Function(String id) onRechazarLlegando,
    required void Function(String id, Map<String, dynamic> s) onAceptarEspera,
    void Function(String id)? onDescartarEspera,
    required String Function(Map<String, dynamic>) getSolicitudId,
    required int Function(String id) segundosRestantes,
    VoidCallback? onVerEnEspera,
  }) {
    if (!shouldShowPanel(
      controller: controller,
      home: home,
      pendientes: pendientes,
    )) {
      return const SizedBox.shrink();
    }

    if (controller.index == 0) {
      return _llegandoTab(
        context: context,
        home: home,
        getSolicitudId: getSolicitudId,
        segundosRestantes: segundosRestantes,
        onAceptar: onAceptarLlegando,
        onRechazar: onRechazarLlegando,
        onVerEnEspera: onVerEnEspera,
      );
    }

    return _enEsperaTab(
      context: context,
      home: home,
      pendientes: pendientes,
      onAceptar: onAceptarEspera,
      onDescartar: onDescartarEspera,
    );
  }

  static Widget _llegandoTab({
    required BuildContext context,
    required ConductorHomeProvider home,
    required String Function(Map<String, dynamic>) getSolicitudId,
    required int Function(String id) segundosRestantes,
    required void Function(String id) onAceptar,
    required void Function(String id) onRechazar,
    VoidCallback? onVerEnEspera,
  }) {
    final lista = home.solicitudesOrdenadas;
    final espera = home.totalSolicitudesEnEspera;
    final soloAvisoEspera = lista.isEmpty && espera > 0;

    Future<void> onRefresh() async {
      try {
        await home.sincronizarSolicitudesPublicadasConductor(
          propagarError: true,
        );
      } catch (_) {}
    }

    if (lista.isEmpty && espera == 0) {
      return const SizedBox.shrink();
    }

    Widget listBody;
    if (soloAvisoEspera) {
      listBody = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        children: [
          Center(
            child: TextButton.icon(
              onPressed: onVerEnEspera,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                espera == 1
                    ? 'Ver 1 servicio en espera'
                    : 'Ver $espera servicios en espera',
              ),
            ),
          ),
        ],
      );
    } else {
      listBody = _serviciosListView(
        context: context,
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final solicitud = lista[index];
          final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(solicitud);
          if (id == null || id.isEmpty) return const SizedBox.shrink();
          final seg = segundosRestantes(id);
          return SolicitudServicioCard(
            solicitud: solicitud,
            marginExterno: false,
            compact: true,
            denseList: true,
            segundosRestantes: seg > 0 ? seg : null,
            distanciaDesdeMi: home.distanciaDesdeConductorTexto(solicitud),
            destacada: index == 0,
            onAceptar: () => onAceptar(id),
            onRechazar: () => onRechazar(id),
          );
        },
      );
    }

    return _panelShell(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: onRefresh,
              child: listBody,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _enEsperaTab({
    required BuildContext context,
    required ConductorHomeProvider home,
    required SolicitudesPendientesProvider pendientes,
    required void Function(String id, Map<String, dynamic> s) onAceptar,
    void Function(String id)? onDescartar,
  }) {
    final lista = pendientes.pendientes;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Future<void> onRefresh() async {
      try {
        await pendientes.refrescar(silencioso: false);
      } catch (_) {}
    }
    final panelH = _listPanelHeight(context, conBarraRefresh: true);

    Widget body;
    if (pendientes.cargando && lista.isEmpty) {
      body = const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (pendientes.error != null && lista.isEmpty) {
      body = RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: panelH - 34 - 24,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 32,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pendientes.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: pendientes.cargando
                            ? null
                            : () => unawaited(
                                  pendientes.refrescar(silencioso: false),
                                ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (lista.isEmpty) {
      const mensaje = 'Sin publicados en Popayán';
      body = RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: panelH - 34 - 24,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      height: 1.35,
                    ),
                    maxLines: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: _serviciosListView(
          context: context,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          itemCount: lista.length,
          itemBuilder: (context, index) {
            final item = lista[index];
            final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(item);
            if (id == null || id.isEmpty) return const SizedBox.shrink();
            final segEspera = home.obtenerSegundosRestantes(id);
            return SolicitudServicioCard(
              solicitud: item,
              marginExterno: false,
              compact: true,
              denseList: true,
              segundosRestantes: segEspera > 0 ? segEspera : null,
              distanciaDesdeMi: pendientes.distanciaDesdeMi(item),
              tiempoPublicado: pendientes.tiempoPublicado(item),
              precioOfertado: pendientes.precioOfertadoDe(item),
              onAceptar: () => onAceptar(id, item),
              onRechazar: onDescartar != null ? () => onDescartar(id) : null,
            );
          },
        ),
      );
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: panelH,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(right: 4, top: 2),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                onPressed: pendientes.cargando
                    ? null
                    : () => unawaited(pendientes.refrescar(silencioso: false)),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Actualizar',
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  /// Lista con separación fija; sin [itemExtent] rígido (evita overflow con destino/botones).
  static Widget _serviciosListView({
    required BuildContext context,
    required int itemCount,
    required Widget? Function(BuildContext, int) itemBuilder,
    EdgeInsets padding = const EdgeInsets.fromLTRB(8, 8, 8, 10),
  }) {
    if (itemCount <= 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: const [SizedBox(height: 1)],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: _listGap),
      itemBuilder: (context, index) {
        final card = itemBuilder(context, index);
        if (card == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topCenter,
          child: card,
        );
      },
    );
  }
}
