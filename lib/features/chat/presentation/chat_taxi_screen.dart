// lib/features/chat/presentation/chat_taxi_screen.dart

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../logic/chat_taxi_controller.dart';
import '../services/chat_taxi_service.dart';
import '../widgets/mensaje_burbuja_widget.dart';
import '../../../core/theme/app_colors.dart';

class ChatTaxiScreen extends StatefulWidget {
  final int servicioId;
  final int miUserId;

  const ChatTaxiScreen({
    Key? key,
    required this.servicioId,
    required this.miUserId,
  }) : super(key: key);

  @override
  State<ChatTaxiScreen> createState() => _ChatTaxiScreenState();
}

class _ChatTaxiScreenState extends State<ChatTaxiScreen>
    with WidgetsBindingObserver {
  late ChatTaxiController _controller;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _enviando = false;
  bool _mostrarMensajesRapidos = true;

  // Mensajes rápidos predefinidos
  final List<String> _mensajesRapidos = [
    '¡Ya voy en camino! 🚗',
    'Llegando en 5 minutos ⏱️',
    'Estoy aquí 📍',
    'Gracias 😊',
    'Un momento por favor ⏳',
    '¿Dónde te encuentras? 📱',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final service = ChatTaxiService();

    _controller = ChatTaxiController(
      service: service,
      servicioId: widget.servicioId,
      miUserId: widget.miUserId,
    );

    // Inicializar (usa Pusher global secundario)
    _controller.inicializar();

    _controller.addListener(_scrollToBottom);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Marcar mensajes como leídos cuando vuelve a la app
      _controller.marcarTodosComoLeidos();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.grey[50],
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_mostrarMensajesRapidos && _controller.mensajes.isEmpty)
              _buildMensajesRapidos(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? AppColors.darkOnSurface : Colors.black87,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Consumer<ChatTaxiController>(
        builder: (context, controller, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          if (controller.cargando && controller.infoChat == null) {
            return Text(
              'Cargando...',
              style: TextStyle(
                color: isDark ? AppColors.darkOnSurface : Colors.black87,
              ),
            );
          }

          return Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? AppColors.darkCard : Colors.grey[300],
                backgroundImage: controller.fotoOtroUsuario != null
                    ? CachedNetworkImageProvider(controller.fotoOtroUsuario!)
                    : null,
                child: controller.fotoOtroUsuario == null
                    ? Icon(
                        Icons.person,
                        size: 20,
                        color: isDark ? AppColors.darkOnSurface : Colors.grey[700],
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Nombre y rol
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.nombreOtroUsuario,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkOnSurface : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      controller.rolOtroUsuario,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        // Botón de refrescar
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: isDark ? AppColors.darkOnSurface : Colors.black87,
          ),
          onPressed: () => _controller.recargarMensajes(),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatTaxiController>(
      builder: (context, controller, _) {
        // Estado de carga inicial
        if (controller.cargando && controller.mensajes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando mensajes...'),
              ],
            ),
          );
        }

        // Error
        if (controller.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar el chat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _controller.inicializar(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        // Sin mensajes
        if (controller.mensajes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.messages_copy,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay mensajes aún',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¡Envía el primero!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Lista de mensajes
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: controller.mensajes.length,
          itemBuilder: (context, index) {
            final mensaje = controller.mensajes[index];
            final esMio = mensaje.remitenteId == widget.miUserId;

            // Mostrar separador de fecha si es necesario
            bool mostrarFecha = false;
            if (index == 0) {
              mostrarFecha = true;
            } else {
              final mensajeAnterior = controller.mensajes[index - 1];
              final diferencia = mensaje.createdAt.difference(
                mensajeAnterior.createdAt,
              );
              if (diferencia.inHours > 1) {
                mostrarFecha = true;
              }
            }

            return Column(
              children: [
                if (mostrarFecha) _buildDateSeparator(mensaje.createdAt),
                MensajeBurbujaWidget(mensaje: mensaje, esMio: esMio),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String texto;
    if (difference.inDays == 0) {
      texto = 'Hoy';
    } else if (difference.inDays == 1) {
      texto = 'Ayer';
    } else if (difference.inDays < 7) {
      final dias = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      texto = dias[date.weekday - 1];
    } else {
      texto = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkOnSurface : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.3) 
                : Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Campo de texto
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  style: TextStyle(
                    color: isDark ? AppColors.darkOnSurface : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  enabled: !_enviando,
                  onSubmitted: (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botón enviar
            Consumer<ChatTaxiController>(
              builder: (context, controller, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: _enviando 
                        ? Colors.grey 
                        : (isDark ? AppColors.accent : AppColors.accent),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _enviando ? null : _enviarMensaje,
                    icon: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMensajesRapidos() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _mensajesRapidos.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _mensajesRapidos[index],
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkOnSurface : Colors.black87,
                ),
              ),
              backgroundColor: isDark ? AppColors.darkBackground : AppColors.white,
              side: BorderSide(
                color: isDark ? AppColors.grey : AppColors.grey,
                width: 1,
              ),
              onPressed: () {
                _textController.text = _mensajesRapidos[index];
                setState(() {
                  _mostrarMensajesRapidos = false;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _enviarMensaje() async {
    final texto = _textController.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    _textController.clear();

    final enviado = await _controller.enviarMensaje(texto);

    setState(() => _enviando = false);

    if (!enviado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al enviar mensaje'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      // Restaurar el texto si falló
      _textController.text = texto;
    } else {
      // Scroll al final después de enviar
      _scrollToBottom();
    }
  }
}
