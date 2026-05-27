import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/providers/solicitudes_pendientes_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_pendiente_quick_card.dart';
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

  /// Altura del panel de contenido (0 = solo mapa visible).
  static double panelHeight(
    BuildContext context, {
    required TabController controller,
    required ConductorHomeProvider home,
    required SolicitudesPendientesProvider pendientes,
  }) {
    final screenH = MediaQuery.sizeOf(context).height;
    final maxH = screenH * (pantallaCompacta(context) ? 0.28 : 0.34);
    if (controller.index == 0) {
      if (home.solicitudesOrdenadas.isEmpty) return 0;
      return maxH.clamp(140, maxH);
    }
    if (pendientes.cargando && pendientes.total == 0) return 56;
    if (pendientes.total == 0) return 44;
    return maxH.clamp(140, maxH);
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
    final h = panelHeight(
      context,
      controller: controller,
      home: home,
      pendientes: pendientes,
    );
    if (h <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: h,
        child: TabBarView(
          controller: controller,
          children: [
            _llegandoTab(
              home: home,
              getSolicitudId: getSolicitudId,
              segundosRestantes: segundosRestantes,
              onAceptar: onAceptarLlegando,
              onRechazar: onRechazarLlegando,
            ),
            _enEsperaTab(
              home: home,
              pendientes: pendientes,
              onAceptar: onAceptarEspera,
              onDescartar: onDescartarEspera,
            ),
          ],
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final solicitud = lista[index];
        final id = getSolicitudId(solicitud);
        if (id.isEmpty) return const SizedBox.shrink();
        final seg = segundosRestantes(id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SolicitudServicioCard(
            solicitud: solicitud,
            segundosRestantes: seg > 0 ? seg : null,
            destacada: index == 0,
            onAceptar: () => onAceptar(id),
            onRechazar: () => onRechazar(id),
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

    if (lista.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                home.radioAccion.activo && !home.radioAccion.sinLimite
                    ? 'Sin publicados a ${home.radioAccion.radioEfectivoKm.round()} km'
                    : 'Sin publicados',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: pendientes.refrescar,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Actualizar',
            ),
          ],
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
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final item = lista[index];
              final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(item);
              if (id == null || id.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ConductorPendienteQuickCard(
                  anchoCompleto: true,
                  solicitud: item,
                  distanciaDesdeMi: pendientes.distanciaDesdeMi(item),
                  tiempoPublicado: pendientes.tiempoPublicado(item),
                  onAceptar: () => onAceptar(id, item),
                  onDescartar:
                      onDescartar != null ? () => onDescartar(id) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
