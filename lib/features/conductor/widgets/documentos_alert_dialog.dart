import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class DocumentosAlertDialog extends StatelessWidget {
  final List<DocumentoConductor> documentosVencidos;
  final List<DocumentoConductor> documentosPorVencer;
  final VoidCallback? onContinuar;

  const DocumentosAlertDialog({
    super.key,
    required this.documentosVencidos,
    required this.documentosPorVencer,
    this.onContinuar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final hayVencidos = documentosVencidos.isNotEmpty;
    final hayPorVencer = documentosPorVencer.isNotEmpty;

    if (!hayVencidos && !hayPorVencer) {
      return const SizedBox.shrink();
    }

    final Color colorPrincipal =
        hayVencidos ? colors.error : colors.tertiary;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.surface,
                colors.surface.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ICONO
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorPrincipal.withValues(alpha: 0.15),
                        colorPrincipal.withValues(alpha: 0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorPrincipal.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    hayVencidos
                        ? Iconsax.info_circle_copy
                        : Iconsax.warning_2_copy,
                    color: colorPrincipal,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 20),

                // TITULO
                Text(
                  hayVencidos
                      ? '⚠️ Documentos Vencidos'
                      : '⏰ Documentos por Vencer',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorPrincipal,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // DESCRIPCIÓN
                Text(
                  hayVencidos
                      ? 'Debes renovar estos documentos lo antes posible para continuar.'
                      : 'Algunos documentos están próximos a vencer.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // VENCIDOS
                if (hayVencidos) ...[
                  _buildDocumentosSection(
                    context,
                    'Vencidos',
                    documentosVencidos,
                    colors.error,
                    Iconsax.close_circle_copy,
                  ),
                  const Divider(height: 20),
                ],

                // POR VENCER
                if (hayPorVencer) ...[
                  _buildDocumentosSection(
                    context,
                    'Por vencer',
                    documentosPorVencer,
                    colors.tertiary,
                    Iconsax.clock_copy,
                  ),
                ],

                const SizedBox(height: 24),

                // BOTONES
                Column(
                  children: [
                    // BOTÓN PRINCIPAL
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/mis-documentos');
                          onContinuar?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrincipal,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Iconsax.document_text_copy),
                        label: Text(
                          hayVencidos
                              ? 'Actualizar ahora'
                              : 'Revisar documentos',
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // BOTÓN "ACTUALIZAR MÁS TARDE"
                
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onContinuar?.call();
                        },
                        icon: const Icon(Iconsax.clock_copy, size: 18),
                        label: const Text('Actualizar más tarde'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentosSection(
    BuildContext context,
    String titulo,
    List<DocumentoConductor> documentos,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    final visibles = documentos.take(3).toList();
    final restantes = documentos.length - visibles.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...visibles.map((doc) => _buildDocumentoItem(context, doc)),

          if (restantes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+$restantes más...',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentoItem(
      BuildContext context, DocumentoConductor doc) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    String mensaje = doc.mensajeAlerta ?? '';

    if (mensaje.isEmpty) {
      if (!doc.requiereVigencia) {
        mensaje = doc.fechaVigenciaDisplay?.trim().isNotEmpty == true
            ? '${doc.etiquetaFecha}: ${doc.fechaVigenciaDisplay}'
            : 'Documento cargado';
      } else {
        final dias = doc.diasRestantes;
        if (dias == null) {
          mensaje = 'Sin fecha de vigencia';
        } else if (dias < 0) {
          mensaje =
              'Vencido hace ${dias.abs()} día${dias.abs() != 1 ? 's' : ''}';
        } else if (dias == 0) {
          mensaje = 'Vence hoy';
        } else {
          mensaje = 'Vence en $dias día${dias != 1 ? 's' : ''}';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.tipoDocumento.tituloDocumento,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  mensaje,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}