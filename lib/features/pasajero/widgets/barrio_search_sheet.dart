import 'package:flutter/material.dart';
import 'package:intellitaxi/core/geo/barrios/barrio.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/pasajero/services/barrios_api_service.dart';

Future<Barrio?> showBarrioSearchSheet({
  required BuildContext context,
  required BarrioResolver resolver,
  String? currentName,
}) {
  return showModalBottomSheet<Barrio>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _BarrioSearchBody(
      resolver: resolver,
      currentName: currentName,
    ),
  );
}

class _BarrioSearchBody extends StatefulWidget {
  const _BarrioSearchBody({required this.resolver, this.currentName});

  final BarrioResolver resolver;
  final String? currentName;

  @override
  State<_BarrioSearchBody> createState() => _BarrioSearchBodyState();
}

class _BarrioSearchBodyState extends State<_BarrioSearchBody> {
  final _controller = TextEditingController();
  List<Barrio> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    final results = await widget.resolver.search(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + inset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Elige el barrio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Buscar barrio…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            if (_searching) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final barrio = _results[i];
                  return ListTile(
                    title: Text(
                      barrio.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: barrio.comuna == null
                        ? null
                        : Text('Comuna ${barrio.comuna}'),
                    selected: barrio.nombre == widget.currentName,
                    selectedColor: AppColors.primary,
                    onTap: () => Navigator.pop(context, barrio),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dejar como “Barrio por confirmar”'),
            ),
          ],
        ),
      ),
    );
  }
}
