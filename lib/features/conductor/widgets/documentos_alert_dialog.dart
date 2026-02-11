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
    final hayVencidos = documentosVencidos.isNotEmpty;
    final hayPorVencer = documentosPorVencer.isNotEmpty;

    if (!hayVencidos && !hayPorVencer) {
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: false, // No permitir cerrar con el botón de atrás
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            // gradient: LinearGradient(
            //   begin: Alignment.topCenter,
            //   end: Alignment.bottomCenter,
            //   colors: [Colors.white, Colors.grey.shade50],
            // ),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
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
                    hayVencidos
                        ? Iconsax.info_circle_copy
                        : Iconsax.warning_2_copy,
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
                    // color: Colors.black87,
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
                    Iconsax.close_circle_copy,
                  ),
                  const SizedBox(height: 12),
                ],

                // Lista de documentos por vencer
                if (hayPorVencer) ...[
                  _buildDocumentosSection(
                    'Por vencer',
                    documentosPorVencer,
                    Colors.orange,
                    Iconsax.clock_copy,
                  ),
                ],

                const SizedBox(height: 24),

                // Botón único - obligatorio ver documentos
                SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navegar a la pantalla de documentos
                  Navigator.pushNamed(context, '/mis-documentos');
                  onContinuar?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hayVencidos ? Colors.red : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Iconsax.document_text_copy, size: 20),
                label: Text(
                  hayVencidos
                      ? 'Actualizar documentos ahora'
                      : 'Revisar documentos',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
        border: Border.all(color: color.withOpacity(0.2), width: 1),
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
    // Usar el mensaje del servidor si está disponible, sino calcular localmente
    String mensaje = doc.mensajeAlerta ?? '';

    if (mensaje.isEmpty) {
      final dias = doc.diasRestantes;
      if (dias == null) {
        mensaje = 'Sin fecha de vigencia';
      } else if (dias < 0) {
        mensaje = 'Vencido hace ${dias.abs()} día${dias.abs() != 1 ? 's' : ''}';
      } else if (dias == 0) {
        mensaje = 'Vence hoy';
      } else {
        mensaje = 'Vence en $dias día${dias != 1 ? 's' : ''}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
