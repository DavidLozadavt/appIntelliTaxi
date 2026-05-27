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
  }) {
    final compact = pantallaCompacta(context);
    var h = 12.0;
    h += chipAltura;
    h += tabBarHeight(context);
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
      return home.solicitudesOrdenadas.isNotEmpty;
    }
    return true;
  }

  /// Tarjetas compactas en lista (~3–4 visibles en pantalla).
  static int _visibleCardsCount(BuildContext context) =>
      pantallaCompacta(context) ? 3 : 4;

  static double _compactCardExtent(BuildContext context) =>
      pantallaCompacta(context) ? 98.0 : 106.0;

  static double _listPanelHeight(
    BuildContext context, {
    required bool conBarraRefresh,
  }) {
    final n = _visibleCardsCount(context);
    final cardH = _compactCardExtent(context);
    var h = cardH * n + 6 * (n - 1) + 12;
    if (conBarraRefresh) h += 34;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxH = screenH * (pantallaCompacta(context) ? 0.36 : 0.40);
    final minH = cardH * 2 + 18 + (conBarraRefresh ? 34 : 0);
    return h.clamp(minH, maxH);
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
  }) {
    final lista = home.solicitudesOrdenadas;
    if (lista.isEmpty) {
      return const SizedBox.shrink();
    }

    Future<void> onRefresh() =>
        home.sincronizarSolicitudesPublicadasConductor();

    return _panelShell(
      context: context,
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final solicitud = lista[index];
            final id = getSolicitudId(solicitud);
            if (id.isEmpty) return const SizedBox.shrink();
            final seg = segundosRestantes(id);
            return SolicitudServicioCard(
              solicitud: solicitud,
              marginExterno: false,
              compact: true,
              segundosRestantes: seg > 0 ? seg : null,
              destacada: index == 0,
              onAceptar: () => onAceptar(id),
              onRechazar: () => onRechazar(id),
            );
          },
        ),
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
    Future<void> onRefresh() => pendientes.refrescar(silencioso: false);
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
    } else if (lista.isEmpty) {
      final mensaje = home.radioAccion.activo && !home.radioAccion.sinLimite
          ? 'Sin servicios a ${home.radioAccion.radioEfectivoKm.round()} km (Popayán)'
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
      body = RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final item = lista[index];
            final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(item);
            if (id == null || id.isEmpty) return const SizedBox.shrink();
            return SolicitudServicioCard(
              solicitud: item,
              marginExterno: false,
              compact: true,
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
                onPressed: pendientes.cargando ? null : pendientes.refrescar,
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
}
