import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_badge_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Socket del chat + polling de respaldo mientras el viaje está activo.
class ChatBadgeLifecycle extends StatefulWidget {
  const ChatBadgeLifecycle({
    super.key,
    required this.servicioId,
    required this.child,
    this.miUserId,
  });

  final int servicioId;
  final int? miUserId;
  final Widget child;

  @override
  State<ChatBadgeLifecycle> createState() => _ChatBadgeLifecycleState();
}

class _ChatBadgeLifecycleState extends State<ChatBadgeLifecycle>
    with WidgetsBindingObserver {
  ChatBadgeProvider? _badgeProvider;
  AuthProvider? _authProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _badgeProvider = context.read<ChatBadgeProvider>();
    _authProvider = context.read<AuthProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  @override
  void didUpdateWidget(ChatBadgeLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.servicioId != widget.servicioId) {
      _reiniciar();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _actualizar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _badgeProvider?.detenerMonitoreo();
    super.dispose();
  }

  int _resolveUserId() {
    if (widget.miUserId != null && widget.miUserId! > 0) {
      return widget.miUserId!;
    }
    return _authProvider?.userId ?? 0;
  }

  void _iniciar() {
    if (!mounted || widget.servicioId <= 0) return;
    final badge = _badgeProvider;
    if (badge == null) return;
    final uid = _resolveUserId();
    if (uid <= 0) return;
    badge.iniciarMonitoreo(widget.servicioId, uid);
  }

  void _reiniciar() {
    if (!mounted) return;
    _badgeProvider?.detenerMonitoreo();
    _iniciar();
  }

  void _actualizar() {
    if (!mounted || widget.servicioId <= 0) return;
    _badgeProvider?.actualizarNoLeidos(widget.servicioId);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Badge numérico sobre un icono de chat.
class ChatUnreadBadge extends StatelessWidget {
  const ChatUnreadBadge({
    super.key,
    required this.servicioId,
    required this.child,
  });

  final int servicioId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatBadgeProvider>(
      builder: (context, badge, _) {
        final count = badge.getNoLeidos(servicioId);
        if (count <= 0) return child;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
