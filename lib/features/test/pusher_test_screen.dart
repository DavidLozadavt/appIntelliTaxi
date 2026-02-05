import 'package:flutter/material.dart';
import '../../config/pusher_config.dart';
import 'dart:convert';

/// Pantalla de prueba para verificar la recepción de eventos de Pusher secundario
class PusherTestScreen extends StatefulWidget {
  const PusherTestScreen({Key? key}) : super(key: key);

  @override
  State<PusherTestScreen> createState() => _PusherTestScreenState();
}

class _PusherTestScreenState extends State<PusherTestScreen> {
  final List<String> _receivedMessages = [];
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _initializePusher();
  }

  Future<void> _initializePusher() async {
    print('🚀 Inicializando Pusher Test Screen...');

    // Suscribirse al canal de prueba secundario
    await _subscribeToTestChannel();
  }

  Future<void> _subscribeToTestChannel() async {
    try {
      // Suscribirse al canal test-secondary-pusher
      await PusherService.subscribeSecondary('test-secondary-pusher');

      // Registrar el handler para el evento test.message
      PusherService.registerEventHandlerSecondary(
        'test-secondary-pusher:test.message',
        _onTestMessage,
      );

      setState(() {
        _isSubscribed = true;
      });

      print(
        '✅ Suscrito a test-secondary-pusher y esperando eventos test.message',
      );
    } catch (e) {
      print('❌ Error al suscribirse: $e');
    }
  }

  void _onTestMessage(dynamic data) {
    print('🎉 ¡Mensaje de prueba recibido!');
    print('📦 Data recibida: $data');

    try {
      // Parsear el JSON si viene como string
      dynamic parsedData = data;
      if (data is String) {
        parsedData = jsonDecode(data);
      }

      final String message = parsedData['message'] ?? parsedData.toString();
      final String timestamp = DateTime.now().toString();

      setState(() {
        _receivedMessages.insert(
          0,
          '[$timestamp]\n$message\n\nData completa: ${jsonEncode(parsedData)}',
        );
      });

      // Mostrar snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Evento recibido: $message'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error procesando mensaje: $e');
      setState(() {
        _receivedMessages.insert(
          0,
          '[${DateTime.now()}]\nError: $e\nData: $data',
        );
      });
    }
  }

  @override
  void dispose() {
    // Desuscribirse al salir
    PusherService.unsubscribeSecondary('test-secondary-pusher');
    PusherService.unregisterEventHandlerSecondary(
      'test-secondary-pusher:test.message',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusher Test - Secondary'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isSubscribed
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSubscribed ? Colors.green : Colors.orange,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isSubscribed
                          ? Icons.check_circle
                          : Icons.hourglass_empty,
                      color: _isSubscribed ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSubscribed
                          ? 'Conectado y esperando eventos'
                          : 'Conectando...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isSubscribed
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Canal: test-secondary-pusher',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Text(
                  'Evento: test.message',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mensajes recibidos: ${_receivedMessages.length}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: _receivedMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sin mensajes aún',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Esperando eventos de Pusher...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _receivedMessages.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${_receivedMessages.length - index}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _receivedMessages[index],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Clear Button
          if (_receivedMessages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _receivedMessages.clear();
                  });
                },
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Limpiar mensajes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
