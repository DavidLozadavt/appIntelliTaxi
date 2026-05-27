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

  /// Evita `minHeight: infinity` cuando el panel no tiene altura acotada (crash al llegar solicitud).
  static double _minHeightForPullRefresh(
    BuildContext context,
    BoxConstraints constraints, {
    double fallbackFraction = 0.18,
    double fallbackMin = 160,
  }) {
    final maxH = constraints.maxHeight;
    if (maxH.isFinite && maxH > 0) return maxH;
    final screenH = MediaQuery.sizeOf(context).height;
    return (screenH * fallbackFraction).clamp(fallbackMin, screenH * 0.45);
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

  /// Altura del panel «En espera» (Llegando usa altura intrínseca de la tarjeta).
  static double panelHeight(
    BuildContext context, {
    required TabController controller,
    required ConductorHomeProvider home,
    required SolicitudesPendientesProvider pendientes,
  }) {
    final screenH = MediaQuery.sizeOf(context).height;
    final maxH = screenH * (pantallaCompacta(context) ? 0.22 : 0.26);
    if (controller.index == 0) {
      return 0;
    }
    if (pendientes.cargando && pendientes.total == 0) return 56;
    if (pendientes.total == 0) return 44;
    return maxH.clamp(140, maxH);
  }

  static double _enEsperaPanelHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return screenH * (pantallaCompacta(context) ? 0.22 : 0.26);
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
        home: home,
        getSolicitudId: getSolicitudId,
        segundosRestantes: segundosRestantes,
        onAceptar: onAceptarLlegando,
        onRechazar: onRechazarLlegando,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enEsperaH = _enEsperaPanelHeight(context);

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: enEsperaH,
        child: _enEsperaTab(
          home: home,
          pendientes: pendientes,
          onAceptar: onAceptarEspera,
          onDescartar: onDescartarEspera,
        ),
      ),
    );
  }

  static Widget _llegandoTab({
    required ConductorHomeProvider home,
    required String Function(Map<String, dynamic>) getSolicitudId,
    required int Function(String id) segundosRestantes,
    required void Function(String id) onAceptar,
    required void Function(String id) onRechazar,
  }) {
    final lista = home.solicitudesOrdenadas;
    Future<void> onRefresh() =>
        home.sincronizarSolicitudesPublicadasConductor();

    if (lista.isEmpty) {
      return const SizedBox.shrink();
    }

    return Builder(
      builder: (context) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: _minHeightForPullRefresh(
                  context,
                  const BoxConstraints(),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < lista.length; index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final solicitud = lista[index];
                        final id = getSolicitudId(solicitud);
                        if (id.isEmpty) return const SizedBox.shrink();
                        final seg = segundosRestantes(id);
                        return SolicitudServicioCard(
                          solicitud: solicitud,
                          marginExterno: false,
                          segundosRestantes: seg > 0 ? seg : null,
                          destacada: index == 0,
                          onAceptar: () => onAceptar(id),
                          onRechazar: () => onRechazar(id),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _enEsperaTab({
    required ConductorHomeProvider home,
    required SolicitudesPendientesProvider pendientes,
    required void Function(String id, Map<String, dynamic> s) onAceptar,
    void Function(String id)? onDescartar,
  }) {
    final lista = pendientes.pendientes;

    if (pendientes.cargando && lista.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    Future<void> onRefresh() => pendientes.refrescar(silencioso: false);

    if (lista.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: _minHeightForPullRefresh(
                    context,
                    constraints,
                    fallbackFraction: 0.12,
                    fallbackMin: 72,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          home.radioAccion.activo && !home.radioAccion.sinLimite
                              ? 'Sin servicios a ${home.radioAccion.radioEfectivoKm.round()} km (Popayán)'
                              : 'Sin publicados en Popayán',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: pendientes.refrescar,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        tooltip: 'Actualizar',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
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
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final item = lista[index];
                final id =
                    ConductorSolicitudPayloadHelper.obtenerSolicitudId(item);
                if (id == null || id.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SolicitudServicioCard(
                    solicitud: item,
                    marginExterno: false,
                    compact: true,
                    distanciaDesdeMi: pendientes.distanciaDesdeMi(item),
                    tiempoPublicado: pendientes.tiempoPublicado(item),
                    precioOfertado: pendientes.precioOfertadoDe(item),
                    onAceptar: () => onAceptar(id, item),
                    onRechazar:
                        onDescartar != null ? () => onDescartar(id) : null,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
