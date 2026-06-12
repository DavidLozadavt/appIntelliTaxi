import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/providers/solicitudes_pendientes_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_oferta_indriver_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/widgets/solicitud_servicio_card.dart';

/// Pestañas compactas bajo el chip «En línea».
class ConductorMapServiciosTabs {
  ConductorMapServiciosTabs._();

  static bool pantallaCompacta(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 680;

  static VoidCallback? _aceptarSiPermitido(
    Map<String, dynamic> solicitud,
    void Function(String id) onAceptar,
  ) {
    if (!ConductorOfertaIndriverHelper.puedeAceptarRechazar(solicitud)) {
      return null;
    }
    final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(solicitud);
    if (id == null || id.isEmpty) return null;
    return () => onAceptar(id);
  }

  static VoidCallback? _rechazarSiPermitido(
    Map<String, dynamic> solicitud,
    void Function(String id) onRechazar,
  ) {
    if (!ConductorOfertaIndriverHelper.puedeAceptarRechazar(solicitud)) {
      return null;
    }
    final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(solicitud);
    if (id == null || id.isEmpty) return null;
    return () => onRechazar(id);
  }

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
    var h = 12.0;
    h += chipAltura;
    h += tabBarHeight(context);
    if (avisoEsperaEnLlegando) {
      h += 44;
    }
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
          home.solicitudesEnEsperaOrdenadas.isNotEmpty ||
          home.totalSolicitudesLlegando > 0 ||
          home.totalSolicitudesEnEspera > 0;
    }
    return pendientes.pendientes.isNotEmpty ||
        pendientes.total > 0 ||
        pendientes.cargando ||
        pendientes.error != null;
  }

  static bool mostrarAvisoEnEsperaEnLlegando({
    required TabController controller,
    required ConductorHomeProvider home,
  }) =>
      controller.index == 0 &&
      home.totalSolicitudesLlegando == 0 &&
      home.totalSolicitudesEnEspera > 0;

  /// Cuántas tarjetas deben verse sin hacer scroll (5 en pantallas bajas, 6 en el resto).
  static int visibleCardsTarget(BuildContext context) =>
      pantallaCompacta(context) ? 5 : 6;

  /// Tarjeta compacta con destino + botones Aceptar/Rechazar.
  static double denseCardWithActionsHeight(BuildContext context) =>
      denseCardItemExtent(context) + 42;

  /// Tarjeta compacta sin destino (recogida + distancia + botones).
  static double denseCardMinHeight(BuildContext context) =>
      pantallaCompacta(context) ? 94.0 : 100.0;

  /// Tarjeta compacta con destino visible.
  static double denseCardItemExtent(BuildContext context) =>
      pantallaCompacta(context) ? 122.0 : 128.0;

  static const double _listGap = 8.0;
  static const double _listPadding = 12.0;
  static const double _tightPanelPadding = 8.0;
  static const double _tightCardGap = 6.0;
  static const double _refreshBarHeight = 34.0;

  /// Evita `ArgumentError` de [num.clamp] cuando min > max (pantallas bajas).
  static double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
  }

  /// Altura del panel según cuántas tarjetas hay (máx. [visibleCardsTarget]).
  static double listPanelHeight(
    BuildContext context, {
    required bool conBarraRefresh,
    int? itemCount,
  }) {
    final maxCards = visibleCardsTarget(context);
    final cardH = denseCardItemExtent(context);
    final refreshH = conBarraRefresh ? _refreshBarHeight : 0.0;

    final count = itemCount ?? maxCards;
    final effectiveCount = count.clamp(1, maxCards);
    final perCard = effectiveCount == 1
        ? denseCardWithActionsHeight(context)
        : cardH;
    final listPad =
        effectiveCount == 1 ? _tightPanelPadding : _listPadding;
    final desired = perCard * effectiveCount +
        _listGap * (effectiveCount - 1).clamp(0, maxCards) +
        listPad +
        refreshH;
    final minH = perCard + listPad + refreshH;

    final screenH = MediaQuery.sizeOf(context).height;
    final topPad = MediaQuery.paddingOf(context).top;
    // Espacio para chip+tabs, dock inferior y FABs.
    const reservedInferior = 188.0;
    const reservedSuperior = 118.0;
    final available = screenH - topPad - reservedSuperior - reservedInferior;
    final maxH = _safeClamp(available, minH, screenH * 0.62);

    return _safeClamp(desired, minH, maxH);
  }

  /// Altura del bloque flotante (mapa / posicionamiento).
  static double panelOuterHeight(
    BuildContext context, {
    required bool conBarraRefresh,
    required int itemCount,
    bool tightPanel = false,
  }) {
    if (tightPanel && !conBarraRefresh && itemCount > 0) {
      final cardH = denseCardMinHeight(context);
      if (itemCount == 1) return cardH + _tightPanelPadding;
      return cardH * itemCount +
          _tightCardGap * (itemCount - 1) +
          _tightPanelPadding;
    }
    return listPanelHeight(
      context,
      conBarraRefresh: conBarraRefresh,
      itemCount: itemCount,
    );
  }

  static bool usarPanelAjustadoLlegando(BuildContext context, int itemCount) =>
      itemCount > 0 && itemCount <= visibleCardsTarget(context);

  static Widget _panelShell({
    required BuildContext context,
    required Widget child,
    int? itemCount,
    bool tight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final material = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: tight
          ? child
          : SizedBox(
              height: listPanelHeight(
                context,
                conBarraRefresh: false,
                itemCount: itemCount,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
    );
    return material;
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
    final soloAvisoEspera =
        home.totalSolicitudesLlegando == 0 && espera > 0;

    Future<void> onRefresh() async {
      try {
        await home.sincronizarSolicitudesPublicadasConductor(
          propagarError: true,
          forzar: true,
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
    } else if (usarPanelAjustadoLlegando(context, lista.length)) {
      listBody = RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: _tightCardGap),
          itemBuilder: (context, index) {
            final solicitud = lista[index];
            final id =
                ConductorSolicitudPayloadHelper.obtenerSolicitudId(solicitud);
            if (id == null || id.isEmpty) return const SizedBox.shrink();
            final seg = segundosRestantes(id);
            final enGracia = home.estaEnGracia(id);
            return SolicitudServicioCard(
              solicitud: solicitud,
              marginExterno: false,
              compact: true,
              denseList: true,
              segundosRestantes: seg > 0 || enGracia ? seg : null,
              enGracia: enGracia,
              distanciaDesdeMi: home.distanciaDesdeConductorTexto(solicitud),
              destacada: index == 0,
              onAceptar: _aceptarSiPermitido(solicitud, onAceptar),
              onRechazar: _rechazarSiPermitido(solicitud, onRechazar),
            );
          },
        ),
      );
      return _panelShell(context: context, tight: true, child: listBody);
    } else {
      listBody = _serviciosListView(
        context: context,
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final solicitud = lista[index];
          final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(solicitud);
          if (id == null || id.isEmpty) return const SizedBox.shrink();
          final seg = segundosRestantes(id);
          final enGracia = home.estaEnGracia(id);
          return SolicitudServicioCard(
            solicitud: solicitud,
            marginExterno: false,
            compact: true,
            denseList: true,
            segundosRestantes: seg > 0 || enGracia ? seg : null,
            enGracia: enGracia,
            distanciaDesdeMi: home.distanciaDesdeConductorTexto(solicitud),
            destacada: index == 0,
            onAceptar: _aceptarSiPermitido(solicitud, onAceptar),
            onRechazar: _rechazarSiPermitido(solicitud, onRechazar),
          );
        },
      );
    }

    return _panelShell(
      context: context,
      itemCount: soloAvisoEspera ? 1 : lista.length,
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: listBody,
      ),
    );
  }

  static Widget _refreshBar({
    required bool cargando,
    required Future<void> Function() onRefresh,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.only(right: 4, top: 2),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
        onPressed: cargando ? null : () => unawaited(onRefresh()),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        tooltip: 'Actualizar',
      ),
    );
  }

  static Widget _esperaServiceCard({
    required Map<String, dynamic> item,
    required ConductorHomeProvider home,
    required SolicitudesPendientesProvider pendientes,
    required void Function(String id, Map<String, dynamic> s) onAceptar,
    void Function(String id)? onDescartar,
  }) {
    final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(item);
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final segEspera = home.obtenerSegundosRestantes(id);
    final enGracia = home.estaEnGracia(id);
    return SolicitudServicioCard(
      solicitud: item,
      marginExterno: false,
      compact: true,
      denseList: true,
      segundosRestantes: segEspera > 0 || enGracia ? segEspera : null,
      enGracia: enGracia,
      distanciaDesdeMi: pendientes.distanciaDesdeMi(item),
      tiempoPublicado: pendientes.tiempoPublicado(item),
      precioOfertado: pendientes.precioOfertadoDe(item),
      onAceptar: ConductorOfertaIndriverHelper.puedeAceptarRechazar(item)
          ? () => onAceptar(id, item)
          : null,
      onRechazar: ConductorOfertaIndriverHelper.puedeAceptarRechazar(item) &&
              onDescartar != null
          ? () => onDescartar(id)
          : null,
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
    final panelH = listPanelHeight(
      context,
      conBarraRefresh: true,
      itemCount: lista.isEmpty ? null : lista.length,
    );

    Widget body;
    if (pendientes.cargando && lista.isEmpty) {
      body = const Center(
        child: AppBrandLoaderCompact(ringSize: 22),
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
      final mensaje = home.sinUbicacionEnApi
          ? 'Activa el GPS para ver solicitudes cercanas'
          : 'Sin publicados en Popayán';
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
      final ajustado = usarPanelAjustadoLlegando(context, lista.length);
      body = RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: ListView.separated(
          shrinkWrap: ajustado,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: _listGap),
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.topCenter,
              child: _esperaServiceCard(
                item: lista[index],
                home: home,
                pendientes: pendientes,
                onAceptar: onAceptar,
                onDescartar: onDescartar,
              ),
            );
          },
        ),
      );

      if (ajustado) {
        return Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _refreshBar(
                cargando: pendientes.cargando,
                onRefresh: onRefresh,
              ),
              body,
            ],
          ),
        );
      }
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
            _refreshBar(
              cargando: pendientes.cargando,
              onRefresh: onRefresh,
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
