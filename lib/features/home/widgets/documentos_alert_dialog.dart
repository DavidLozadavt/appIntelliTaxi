import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/home/data/documento_conductor_model.dart';

class DocumentosAlertDialog extends StatelessWidget {
  final List<DocumentoConductor> documentosVencidos;
  final List<DocumentoConductor> documentosPorVencer;
  final VoidCallback? onContinuar;

  const DocumentosAlertDialog({
    Key? key,
    required this.documentosVencidos,
    required this.documentosPorVencer,
    this.onContinuar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hayVencidos = documentosVencidos.isNotEmpty;
    final hayPorVencer = documentosPorVencer.isNotEmpty;

    if (!hayVencidos && !hayPorVencer) {
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de alerta con animación
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hayVencidos
                      ? [
                          Colors.red.withOpacity(0.15),
                          Colors.red.withOpacity(0.05),
                        ]
                      : [
                          Colors.orange.withOpacity(0.15),
                          Colors.orange.withOpacity(0.05),
                        ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (hayVencidos ? Colors.red : Colors.orange)
                        .withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                hayVencidos ? Icons.error_outline : Icons.warning_amber,
                color: hayVencidos ? Colors.red : Colors.orange,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text(
              hayVencidos
                  ? '⚠️ Documentos Vencidos'
                  : '⏰ Documentos por Vencer',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Descripción
            Text(
              hayVencidos
                  ? 'Tienes documentos vencidos que debes renovar lo antes posible.'
                  : 'Algunos de tus documentos están próximos a vencer.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Lista de documentos vencidos
            if (hayVencidos) ...[
              _buildDocumentosSection(
                'Vencidos',
                documentosVencidos,
                Colors.red,
                Icons.cancel,
              ),
              const SizedBox(height: 12),
            ],

            // Lista de documentos por vencer
            if (hayPorVencer) ...[
              _buildDocumentosSection(
                'Por vencer',
                documentosPorVencer,
                Colors.orange,
                Icons.access_time,
              ),
            ],

            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Ver después',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: hayVencidos ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onContinuar?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hayVencidos ? Colors.red : AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      hayVencidos ? 'Entendido' : 'Continuar',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentosSection(
    String titulo,
    List<DocumentoConductor> documentos,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...documentos.map((doc) => _buildDocumentoItem(doc, color)),
        ],
      ),
    );
  }

  Widget _buildDocumentoItem(DocumentoConductor doc, Color color) {
    final dias = doc.diasRestantes;
    String mensaje = '';

    if (dias == null) {
      mensaje = 'Sin fecha de vigencia';
    } else if (dias < 0) {
      mensaje = 'Vencido hace ${dias.abs()} día${dias.abs() != 1 ? 's' : ''}';
    } else if (dias == 0) {
      mensaje = 'Vence hoy';
    } else {
      mensaje = 'Vence en $dias día${dias != 1 ? 's' : ''}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  mensaje,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
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
