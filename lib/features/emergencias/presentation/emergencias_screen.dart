import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/emergencia_provider.dart';

class EmergenciasScreen extends StatefulWidget {
  const EmergenciasScreen({super.key});

  @override
  State<EmergenciasScreen> createState() =>
      _EmergenciasScreenState();
}

class _EmergenciasScreenState
    extends State<EmergenciasScreen> {

  final List<Map<String, dynamic>>
      tiposEmergencia = [
    {
      "titulo": "Robo",
      "icon": Icons.gpp_bad,
      "color": Colors.red,
      "tipo": "ROBO",
    },
    {
      "titulo": "Accidente",
      "icon": Icons.car_crash,
      "color": Colors.orange,
      "tipo": "ACCIDENTE",
    },
    {
      "titulo": "Emergencia Médica",
      "icon": Icons.medical_services,
      "color": Colors.blue,
      "tipo": "EMERGENCIAMEDICA",
    },
    {
      "titulo": "Cliente Agresivo",
      "icon": Icons.warning_amber_rounded,
      "color": Colors.deepOrange,
      "tipo": "CLIENTEAGRESIVO",
    },
    {
      "titulo": "Falla Mecánica",
      "icon": Icons.build_circle,
      "color": Colors.amber,
      "tipo": "FALLAMECANICA",
    },
  ];

  Future<void> enviarEmergencia(
    String tipo,
  ) async {

    final provider =
        context.read<EmergenciaProvider>();

    final ok =
        await provider.enviarEmergencia(
      idConductor: 1,
      idVehiculo: 18,
      idTurno: 50,
      lat: 4.711,
      lng: -74.0721,
      tipo: tipo,
      descripcion:
          "Emergencia enviada desde app",
    );

    if (!mounted) return;

    if (ok) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            "Emergencia enviada: $tipo",
          ),
        ),
      );

    } else {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            "Error al enviar emergencia",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final emergenciaProvider =
        context.watch<EmergenciaProvider>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Emergencias",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [

          Container(
            width: double.infinity,
            margin:
                const EdgeInsets.all(16),
            padding:
                const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.red.shade900,
                        Colors.red.shade600,
                      ]
                    : [
                        Colors.red,
                        Colors.redAccent,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red
                      .withOpacity(0.25),
                  blurRadius: 20,
                  offset:
                      const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: const [

                Icon(
                  Icons.sos,
                  color: Colors.white,
                  size: 70,
                ),

                SizedBox(height: 14),

                Text(
                  "Botón de Emergencia",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  "Selecciona el tipo de emergencia para notificar a la central.",
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              itemCount:
                  tiposEmergencia.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemBuilder:
                  (context, index) {

                final item =
                    tiposEmergencia[index];

                return InkWell(
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                  onTap:
                      emergenciaProvider
                              .isLoading
                          ? null
                          : () {

                              showDialog(
                                context:
                                    context,
                                builder:
                                    (_) {

                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                        24,
                                      ),
                                    ),
                                    title: Text(
                                      item[
                                          'titulo'],
                                    ),
                                    content:
                                        const Text(
                                      "¿Deseas enviar esta alerta de emergencia?",
                                    ),
                                    actions: [

                                      TextButton(
                                        onPressed:
                                            () {

                                          Navigator.pop(
                                            context,
                                          );
                                        },
                                        child:
                                            const Text(
                                          "Cancelar",
                                        ),
                                      ),

                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              item[
                                                  'color'],
                                          foregroundColor:
                                              Colors
                                                  .white,
                                        ),
                                        onPressed:
                                            () async {

                                          Navigator.pop(
                                            context,
                                          );

                                          await enviarEmergencia(
                                            item[
                                                'tipo'],
                                          );
                                        },
                                        child:
                                            const Text(
                                          "Enviar",
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 250,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          theme.cardColor,
                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors
                              .black
                              .withOpacity(
                            0.06,
                          ),
                          blurRadius: 10,
                          offset:
                              const Offset(
                            0,
                            4,
                          ),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [

                        Container(
                          padding:
                              const EdgeInsets
                                  .all(18),
                          decoration:
                              BoxDecoration(
                            color: item[
                                    'color']
                                .withOpacity(
                              0.12,
                            ),
                            shape: BoxShape
                                .circle,
                          ),
                          child: Icon(
                            item['icon'],
                            color: item[
                                'color'],
                            size: 40,
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                10,
                          ),
                          child: Text(
                            item[
                                'titulo'],
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                              fontSize:
                                  15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.red,
                  foregroundColor:
                      Colors.white,
                  elevation: 4,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                onPressed:
                    emergenciaProvider
                            .isLoading
                        ? null
                        : () async {

                            await enviarEmergencia(
                              "ROBO",
                            );
                          },
                child:
                    emergenciaProvider
                            .isLoading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors
                                      .white,
                              strokeWidth:
                                  2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: const [

                              Icon(
                                Icons.sos,
                                size: 26,
                              ),

                              SizedBox(
                                width: 10,
                              ),

                              Text(
                                "EMERGENCIA RÁPIDA",
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize:
                                      16,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}