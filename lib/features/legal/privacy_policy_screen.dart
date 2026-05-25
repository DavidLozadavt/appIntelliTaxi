import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _supportEmail = '[REEMPLAZAR_CON_CORREO_DE_SOPORTE]';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Política de privacidad',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'TaxbelUrbano',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fecha de entrada en vigencia: 25 de mayo de 2026',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Resumen',
            children: const [
              'TaxbelUrbano es una aplicación para solicitar y gestionar servicios de taxi. Esta política explica cómo accedemos, recopilamos, usamos, almacenamos y compartimos información de pasajeros, conductores y usuarios vinculados a empresas de transporte.',
              'Al usar la aplicación, aceptas el tratamiento de tus datos conforme a esta política.',
            ],
          ),
          _Section(
            title: 'Información que recopilamos',
            bullets: const [
              'Datos de cuenta e identificación: nombre, apellidos, correo, teléfono, dirección, tipo y número de identificación, fecha de nacimiento, sexo, rol, permisos y empresa asociada.',
              'Datos de autenticación: contraseña para validar la cuenta, token de sesión, token del dispositivo para notificaciones y preferencias locales.',
              'Ubicación aproximada y precisa, incluyendo origen, destino y ubicación del conductor durante turnos o servicios activos.',
              'Historial de viajes, direcciones, coordenadas, estado del servicio, fechas, duración, distancia, valores, calificaciones y comentarios.',
              'Datos de conductor y vehículo, como documentos, vigencias, fotos o archivos cargados, placa, marca, modelo, color, turnos, sanciones y disponibilidad.',
              'Fotos seleccionadas o capturadas por el usuario para perfil, documentos, vehículo u otros soportes.',
              'Mensajes de chat, notificaciones, alertas operativas e información técnica necesaria para soporte y seguridad.',
            ],
          ),
          _Section(
            title: 'Permisos del dispositivo',
            bullets: const [
              'Ubicación precisa, aproximada y en segundo plano para conectar pasajeros y conductores, mostrar mapas, recibir solicitudes cercanas y hacer seguimiento de servicios activos.',
              'Cámara y fotos para capturar o seleccionar imágenes de perfil, documentos o soportes.',
              'Notificaciones para informar solicitudes, mensajes, cambios de estado y alertas importantes.',
              'Internet para comunicarse con nuestros servidores y servicios externos.',
              'Servicio en primer plano, actividad en segundo plano y superposición en pantalla en Android cuando sean necesarios para la operación del conductor.',
              'Audio o ajustes de audio si una función de la app lo requiere para alertas o interacción por voz.',
            ],
          ),
          _Section(
            title: 'Uso de la información',
            bullets: const [
              'Crear, autenticar y administrar cuentas.',
              'Solicitar, aceptar, asignar, iniciar, seguir, cancelar y finalizar servicios de taxi.',
              'Mostrar mapas, rutas, ubicación de pasajeros y conductores.',
              'Calcular distancias, tiempos, tarifas estimadas y navegación.',
              'Enviar notificaciones push, alertas operativas y mensajes relacionados con el servicio.',
              'Validar documentos, vehículos, turnos, sanciones, estados de vinculación y disponibilidad.',
              'Prestar soporte, mejorar estabilidad, mantener seguridad y cumplir obligaciones legales.',
            ],
          ),
          _Section(
            title: 'Compartición de información',
            children: const ['No vendemos información personal.'],
            bullets: const [
              'Podemos compartir datos entre pasajero y conductor asignado, como nombre, ubicación de recogida, destino, datos de contacto necesarios, datos del vehículo y estado del servicio.',
              'Podemos compartir información con empresas, administradores o personal autorizado para gestionar conductores, vehículos, documentos, turnos, sanciones, servicios o soporte.',
              'Podemos usar proveedores tecnológicos para backend, alojamiento, mapas, rutas, geocodificación, notificaciones push y comunicación en tiempo real.',
              'Podemos compartir información con autoridades competentes cuando exista obligación legal o necesidad de proteger usuarios y terceros.',
            ],
          ),
          _Section(
            title: 'Servicios de terceros',
            bullets: const [
              'Google Maps Platform para mapas, rutas, ubicaciones y geocodificación.',
              'Firebase Cloud Messaging para notificaciones push.',
              'Pusher para comunicación en tiempo real.',
              'Servicios de backend y almacenamiento operados por TaxbelUrbano o sus proveedores.',
            ],
          ),
          _Section(
            title: 'Seguridad y conservación',
            children: const [
              'Aplicamos medidas técnicas y organizativas razonables para proteger la información, incluyendo comunicación con servidores, controles de acceso y manejo de sesiones.',
              'Conservamos la información mientras sea necesaria para prestar el servicio, mantener la cuenta, cumplir obligaciones legales, resolver disputas, prevenir fraude, generar historial operativo o atender requerimientos administrativos.',
            ],
          ),
          _Section(
            title: 'Derechos del usuario',
            children: const [
              'Según la ley aplicable, puedes solicitar acceso, corrección, actualización, eliminación, revocación de autorizaciones o información sobre el uso de tus datos. Para ejercer estos derechos, escribe a $_supportEmail.',
              'Podemos verificar la identidad del solicitante antes de atender una solicitud. Algunos datos pueden conservarse cuando sean necesarios por obligaciones legales, seguridad, prevención de fraude, registros contables, historial de servicios o defensa de reclamaciones.',
            ],
          ),
          _Section(
            title: 'Menores y transferencias',
            children: const [
              'TaxbelUrbano no está dirigida a menores de edad. Si identificamos datos de un menor sin autorización válida, tomaremos medidas razonables para eliminar o limitar dicha información.',
              'Algunos proveedores tecnológicos pueden procesar información en servidores ubicados fuera del país del usuario, bajo medidas razonables de seguridad.',
            ],
          ),
          _Section(
            title: 'Cambios y contacto',
            children: const [
              'Podemos actualizar esta política para reflejar cambios legales, técnicos u operativos. Publicaremos la versión actualizada indicando la fecha vigente.',
              'Para preguntas, solicitudes o reclamos de privacidad, contáctanos en $_supportEmail.',
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> children;
  final List<String> bullets;

  const _Section({
    required this.title,
    this.children = const [],
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.45)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Iconsax.document_text_copy,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final paragraph in children) ...[
            Text(paragraph),
            const SizedBox(height: 8),
          ],
          for (final item in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 8, right: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
