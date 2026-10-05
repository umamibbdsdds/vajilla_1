import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';

const String kBaseUrl = 'http://10.198.197.181:3000';

// ─────────────────────────────────────────────
// PALETA DE DISEÑO PREMIUM Y MODERNA
// ─────────────────────────────────────────────
const kPrimary     = Color(0xFFC0392B); // rojo INFRAMEN
const kPrimaryDark = Color(0xFF96281B);
const kPrimaryDeep = Color(0xFF0F172A); // casi negro slate
const kSurface     = Color(0xFFFFFFFF);
const kBackground  = Color(0xFFF1F4F8);
const kBorder      = Color(0xFFE4EAF2);
const kTextMain    = Color(0xFF0F172A);
const kTextSub     = Color(0xFF64748B);
const kGreen       = Color(0xFF16A34A);
const kBlue        = Color(0xFF2563EB);
const kAmber       = Color(0xFFD97706);

// ─────────────────────────────────────────────
// SOMBRAS GLOBALES
// ─────────────────────────────────────────────
const kShadowSoft = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x08000000), blurRadius: 2,  offset: Offset(0, 1)),
];

// ─────────────────────────────────────────────
// NOTIFICACIONES
// ─────────────────────────────────────────────
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> inicializarNotificacionesNativas() async {
  const AndroidInitializationSettings initAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: initAndroid);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }
}

Future<void> mostrarNotificacionLocal(String titulo, String cuerpo,
    {bool esError = false}) async {
  final AndroidNotificationDetails android = AndroidNotificationDetails(
    'canal_cafetin_inframen_high',
    'Notificaciones Cafetín',
    channelDescription: 'Avisos en tiempo real sobre retiros y devoluciones',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    playSound: true,
    enableVibration: true,
    color: esError ? const Color(0xFFDC2626) : kPrimary,
    styleInformation: BigTextStyleInformation(cuerpo),
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    titulo,
    cuerpo,
    NotificationDetails(android: android),
  );
}

OverlayEntry? _notifActiva;

void mostrarNotificacionApp(String titulo, String cuerpo,
    {bool esError = false}) {
  mostrarNotificacionLocal(titulo, cuerpo, esError: esError);

  final context = navigatorKey.currentContext;
  if (context == null) return;

  _notifActiva?.remove();
  _notifActiva = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  final topPadding = MediaQuery.of(context).padding.top;
  final bgColor = esError ? const Color(0xFFDC2626) : kPrimaryDeep;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopNotification(
      titulo: titulo,
      cuerpo: cuerpo,
      bgColor: bgColor,
      esError: esError,
      topPadding: topPadding,
      onDismiss: () {
        entry.remove();
        if (_notifActiva == entry) _notifActiva = null;
      },
    ),
  );

  _notifActiva = entry;
  overlay.insert(entry);
}

class _TopNotification extends StatefulWidget {
  final String titulo;
  final String cuerpo;
  final Color bgColor;
  final bool esError;
  final double topPadding;
  final VoidCallback onDismiss;

  const _TopNotification({
    required this.titulo,
    required this.cuerpo,
    required this.bgColor,
    required this.esError,
    required this.topPadding,
    required this.onDismiss,
  });

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();
    Future.delayed(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.esError
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                                letterSpacing: 0.1)),
                        const SizedBox(height: 3),
                        Text(widget.cuerpo,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.close_rounded,
                      color: Colors.white.withOpacity(0.6), size: 18),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await inicializarNotificacionesNativas();
  runApp(const CocinaEscolarApp());
}

class CocinaEscolarApp extends StatelessWidget {
  const CocinaEscolarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Cocina Escolar INFRAMEN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
          secondary: kPrimaryDark,
          surface: kSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: kBackground,
        cardTheme: CardTheme(
          elevation: 0,
          color: kSurface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kBorder, width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimary, width: 1.8),
          ),
          labelStyle: const TextStyle(color: kTextSub, fontSize: 14),
          prefixIconColor: kTextSub,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ─────────────────────────────────────────────
// COMPONENTES COMPARTIDOS
// ─────────────────────────────────────────────
PreferredSizeWidget _buildAppBar(String title, {List<Widget>? actions}) {
  return AppBar(
    title: Text(title),
    actions: actions,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryDark, kPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
  );
}

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
              color: kPrimary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(text,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kTextMain,
              letterSpacing: -0.2)),
    ]),
  );
}

// ─────────────────────────────────────────────
// HOME PAGE
// ─────────────────────────────────────────────
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryDeep, kPrimary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(35),
                    bottomRight: Radius.circular(35),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                                  SizedBox(width: 6),
                                  Text('Sistema Activo',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const Text(
                              'INFRAMEN',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Image.asset(
                          'assets/icon/Logo_IN.PNG',
                          width: 170,
                          height: 170,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.school_rounded,
                              size: 100,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Control de Cafetería',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Sistema de Gestión de Vajilla y Préstamos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Módulos Principales'),
                  const SizedBox(height: 12),
                  _ModuloCardImage(
                    imagePath: 'assets/icon/Utensilios.png',
                    titulo: 'Entrega de Alimentos',
                    subtitulo: 'Retiros, préstamos y devoluciones de vajilla',
                    gradientColors: const [Color(0xFFC0392B), Color(0xFF96281B)],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EntregaModuloPage())),
                  ),
                  const SizedBox(height: 16),
                  _ModuloCardImage(
                    imagePath: 'assets/icon/inventario_IN.png',
                    titulo: 'Inventario y Reportes',
                    subtitulo: 'Estadísticas del día, informes históricos y exportación',
                    gradientColors: const [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const InventarioModuloPage())),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuloCardImage extends StatelessWidget {
  final String imagePath;
  final String titulo;
  final String subtitulo;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _ModuloCardImage({
    required this.imagePath,
    required this.titulo,
    required this.subtitulo,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitulo,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
          ]),
        ),
      ),
    );
  }
}

class _AccesoCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  const _AccesoCard({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder, width: 1),
            boxShadow: kShadowSoft,
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: kTextMain,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 4),
                  Text(subtitulo,
                      style: const TextStyle(
                          fontSize: 12.5, color: kTextSub, height: 1.4)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: color),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MÓDULO 1: ENTREGA
// ─────────────────────────────────────────────
class EntregaModuloPage extends StatelessWidget {
  const EntregaModuloPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Entrega de Alimentos'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 4),
          _AccesoCard(
            icon: Icons.qr_code_scanner_rounded,
            titulo: 'Registrar Retiro',
            subtitulo: 'Escanear carnet y registrar préstamo de utensilio',
            color: kPrimary,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RegistrarPage())),
          ),
          const SizedBox(height: 16),
          _AccesoCard(
            icon: Icons.assignment_return_rounded,
            titulo: 'Pendientes y Devoluciones',
            subtitulo: 'Seleccionar modo de devolución y escanear carnet',
            color: kPrimaryDeep,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PendientesPage())),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MÓDULO 2: INVENTARIO
// ─────────────────────────────────────────────
class InventarioModuloPage extends StatefulWidget {
  const InventarioModuloPage({super.key});

  @override
  State<InventarioModuloPage> createState() => _InventarioModuloPageState();
}

class _InventarioModuloPageState extends State<InventarioModuloPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Inventario y Reportes'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 4),
          _AccesoCard(
            icon: Icons.inventory_2_rounded,
            titulo: 'Gestión de Inventario (CRUD)',
            subtitulo: 'Agregar, editar y eliminar utensilios en tiempo real',
            color: kPrimary,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const InventarioCrudPage())),
          ),
          const SizedBox(height: 16),
          _AccesoCard(
            icon: Icons.donut_large_rounded,
            titulo: 'Estadísticas del Día',
            subtitulo: 'Gráficos de barras y circulares sincronizados en tiempo real',
            color: kBlue,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EstadisticasPage())),
          ),
          const SizedBox(height: 16),
          _AccesoCard(
            icon: Icons.picture_as_pdf_rounded,
            titulo: 'Informes Históricos',
            subtitulo: 'Consultar fechas anteriores y exportar PDF / Excel',
            color: kGreen,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const InformesPage())),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: CRUD INVENTARIO
// ─────────────────────────────────────────────
class InventarioCrudPage extends StatefulWidget {
  const InventarioCrudPage({super.key});

  @override
  State<InventarioCrudPage> createState() => _InventarioCrudPageState();
}

class _InventarioCrudPageState extends State<InventarioCrudPage> {
  List<dynamic> utensilios = [];
  final tipoController = TextEditingController();
  final cantidadController = TextEditingController();
  bool _cargando = false;

  static const _iconoTipo = {
    'Plato': Icons.dinner_dining,
    'Vaso': Icons.local_drink_rounded,
    'Taza': Icons.coffee_rounded,
  };

  static const _colorTipo = {
    'Plato': kBlue,
    'Vaso': kAmber,
    'Taza': kPrimary,
  };

  @override
  void initState() {
    super.initState();
    obtenerInventario();
  }

  @override
  void dispose() {
    tipoController.dispose();
    cantidadController.dispose();
    super.dispose();
  }

  Future<void> obtenerInventario() async {
    setState(() => _cargando = true);
    try {
      final url = Uri.parse('$kBaseUrl/utensilios');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          utensilios = data is List ? data : [];
        });
      }
    } catch (_) {
      mostrarNotificacionApp('Error', 'No se pudo cargar el inventario', esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> agregarUtensilio() async {
    final tipoTexto = tipoController.text.trim();
    final cantidadTexto = cantidadController.text.trim();

    if (tipoTexto.isEmpty || cantidadTexto.isEmpty) {
      mostrarNotificacionApp('Aviso', 'Completa todos los campos obligatorios', esError: true);
      return;
    }

    final cantidadNumero = int.tryParse(cantidadTexto);
    if (cantidadNumero == null || cantidadNumero < 0) {
      mostrarNotificacionApp('Aviso', 'Ingresa una cantidad entera válida (>= 0)', esError: true);
      return;
    }

    try {
      final url = Uri.parse('$kBaseUrl/utensilios');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tipo': tipoTexto,
          'cantidad': cantidadNumero,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        tipoController.clear();
        cantidadController.clear();
        mostrarNotificacionApp('Éxito', 'Utensilio agregado correctamente');
        await obtenerInventario();
      } else {
        final errorData = jsonDecode(response.body);
        mostrarNotificacionApp('Error', errorData['mensaje'] ?? 'No se pudo agregar', esError: true);
      }
    } catch (_) {
      mostrarNotificacionApp('Error', 'Falla de conexión con el servidor', esError: true);
    }
  }

  Future<void> editarUtensilio(int id, String tipoActual, int cantidadActual) async {
    final editTipoController = TextEditingController(text: tipoActual);
    final editCantidadController = TextEditingController(text: cantidadActual.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar Utensilio', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editTipoController,
              decoration: const InputDecoration(labelText: 'Tipo de utensilio'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editCantidadController,
              decoration: const InputDecoration(labelText: 'Cantidad Inicial / Stock'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: kTextSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final url = Uri.parse('$kBaseUrl/utensilios/$id');
                final response = await http.put(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'tipo': editTipoController.text.trim(),
                    'cantidad': int.parse(editCantidadController.text.trim()),
                  }),
                );
                if (response.statusCode == 200 || response.statusCode == 201) {
                  mostrarNotificacionApp('Éxito', 'Utensilio actualizado correctamente');
                  obtenerInventario();
                } else {
                  mostrarNotificacionApp('Error', 'No se pudo actualizar el registro', esError: true);
                }
              } catch (_) {
                mostrarNotificacionApp('Error', 'Falla de conexión al actualizar', esError: true);
              }
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> eliminarUtensilio(int id) async {
    try {
      final url = Uri.parse('$kBaseUrl/utensilios/$id');
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        mostrarNotificacionApp('Aviso', 'Utensilio eliminado');
        obtenerInventario();
      } else {
        final errorData = jsonDecode(response.body);
        mostrarNotificacionApp('Error', errorData['mensaje'] ?? 'No se pudo eliminar', esError: true);
      }
    } catch (_) {
      mostrarNotificacionApp('Error', 'No se pudo eliminar', esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(
        'Gestión de Inventario',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: obtenerInventario,
            tooltip: 'Refrescar Inventario',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kBorder),
                boxShadow: kShadowSoft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nuevo Utensilio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kTextMain)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: tipoController,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de utensilio (Ej: Plato, Vaso, Taza)',
                      prefixIcon: Icon(Icons.kitchen_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad Inicial / Stock',
                      prefixIcon: Icon(Icons.pin_rounded),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: agregarUtensilio,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Agregar a Inventario'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Lista Inicial en Inventario'),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: kPrimary))
                  : utensilios.isEmpty
                      ? const Center(child: Text('Sin utensilios registrados', style: TextStyle(color: kTextSub)))
                      : ListView.separated(
                          itemCount: utensilios.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = utensilios[index];
                            final id = item['id'] ?? index + 1;
                            final tipo = item['tipo'] ?? 'Utensilio';
                            final cantidad = int.tryParse((item['cantidad'] ?? 0).toString()) ?? 0;
                            final colorItem = _colorTipo[tipo] ?? kPrimary;
                            final iconoItem = _iconoTipo[tipo] ?? Icons.kitchen;

                            return Container(
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: kBorder),
                                boxShadow: kShadowSoft,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: colorItem.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(iconoItem, color: colorItem, size: 24),
                                ),
                                title: Text(tipo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextMain)),
                                subtitle: Text("Cantidad inicial disponible: $cantidad", style: const TextStyle(fontSize: 12.5, color: kTextSub)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: kBlue),
                                      onPressed: () => editarUtensilio(id, tipo, cantidad),
                                      tooltip: 'Editar',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                      onPressed: () => eliminarUtensilio(id),
                                      tooltip: 'Eliminar',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: REGISTRAR RETIRO
// ─────────────────────────────────────────────
class RegistrarPage extends StatefulWidget {
  const RegistrarPage({super.key});
  @override
  State<RegistrarPage> createState() => _RegistrarPageState();
}

class _RegistrarPageState extends State<RegistrarPage> {
  final _carnetCtrl = TextEditingController();
  String _tipo = 'Plato';
  bool _cargando = false;
  bool _autoGuardado = true;

  static const _tipos = ['Plato', 'Vaso', 'Taza'];
  static const _iconoTipo = {
    'Plato': Icons.dinner_dining,
    'Vaso': Icons.local_drink_rounded,
    'Taza': Icons.coffee_rounded,
  };
  static const _colorTipo = {
    'Plato': kBlue,
    'Vaso': kAmber,
    'Taza': kPrimary,
  };

  @override
  void dispose() {
    _carnetCtrl.dispose();
    super.dispose();
  }

  void _abrirEscaner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EscaneoPage(
          onCodigoEscaneado: (codigo) {
            setState(() => _carnetCtrl.text = codigo);
            if (_autoGuardado) {
              _procesarRetiro(codigo);
            } else {
              mostrarNotificacionApp(
                  'Código Capturado', 'Carnet $codigo listo.');
            }
          },
        ),
      ),
    );
  }

  Future<void> _procesarRetiro(String codigo) async {
    if (codigo.trim().isEmpty) return;
    setState(() => _cargando = true);
    try {
      final estResp = await http
          .get(Uri.parse('$kBaseUrl/estudiante/$codigo'))
          .timeout(const Duration(seconds: 10));
      if (estResp.statusCode == 404) {
        if (!mounted) return;
        _mostrarDialogoEstudianteNoEncontrado(codigo);
        return;
      }
      if (estResp.statusCode != 200) {
        mostrarNotificacionApp('Error de Servidor',
            'Respuesta inesperada (${estResp.statusCode})',
            esError: true);
        return;
      }
      final estudianteId = jsonDecode(estResp.body)['estudiante']['id'];
      final retResp = await http.post(
        Uri.parse('$kBaseUrl/retiro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'estudiante_id': estudianteId, 'tipo': _tipo}),
      ).timeout(const Duration(seconds: 10));
      if (retResp.statusCode == 200 || retResp.statusCode == 201) {
        mostrarNotificacionApp('¡Préstamo Exitoso!',
            'Retiro de $_tipo para carnet $codigo');
        _carnetCtrl.clear();
      } else {
        mostrarNotificacionApp('Error', 'Error al registrar el retiro (${retResp.statusCode})',
            esError: true);
      }
    } on SocketException {
      mostrarNotificacionApp('Sin Conexión', 'No hay red. Verifica Wi-Fi.', esError: true);
    } catch (_) {
      mostrarNotificacionApp('Aviso', 'Respuesta tardía del servidor. Dato posiblemente registrado.',
          esError: false);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoEstudianteNoEncontrado(String codigo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Estudiante no registrado',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
            'El código "$codigo" no existe en la base de datos.\n¿Deseas registrar a este estudiante ahora?',
            style: const TextStyle(color: kTextSub, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: kTextSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RegistrarEstudiantePage(codigoInicial: codigo)),
              );
            },
            child: const Text('Registrar Alumno'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Registrar Retiro'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kBorder),
              boxShadow: kShadowSoft,
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.outbox_rounded,
                        color: kPrimary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Control de Préstamo',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: kTextMain)),
                        SizedBox(height: 2),
                        Text('Escanea o ingresa el carnet del alumno',
                            style: TextStyle(fontSize: 12.5, color: kTextSub)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                const Divider(color: kBorder, height: 1),
                const SizedBox(height: 20),

                _ToggleRow(
                  icon: _autoGuardado
                      ? Icons.bolt_rounded
                      : Icons.touch_app_rounded,
                  iconColor: _autoGuardado ? kGreen : kTextSub,
                  titulo: 'Guardado automático al escanear',
                  subtitulo: _autoGuardado
                      ? 'Procesa al instante sin confirmación'
                      : 'Requiere pulsar el botón manualmente',
                  value: _autoGuardado,
                  activeColor: kGreen,
                  onChanged: (v) => setState(() => _autoGuardado = v),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _carnetCtrl,
                  decoration: InputDecoration(
                    labelText: 'Carnet / Código de barras',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt_rounded,
                          color: kPrimary),
                      onPressed: _abrirEscaner,
                      tooltip: 'Escanear con cámara',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text('Tipo de utensilio',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextSub)),
                const SizedBox(height: 10),
                Row(
                  children: _tipos.map((t) {
                    final sel = _tipo == t;
                    final col = _colorTipo[t] ?? kPrimary;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tipo = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 6),
                          decoration: BoxDecoration(
                            color: sel ? col : kSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: sel ? col : kBorder, width: 1.5),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                        color: col.withOpacity(0.28),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4))
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconoTipo[t],
                                  color: sel ? Colors.white : col, size: 24),
                              const SizedBox(height: 6),
                              Text(t,
                                  style: TextStyle(
                                      color: sel ? Colors.white : kTextSub,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _cargando
                        ? null
                        : () => _procesarRetiro(_carnetCtrl.text.trim()),
                    icon: _cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Icon(Icons.outbox_rounded),
                    label: Text(
                        _cargando ? 'Procesando...' : 'Registrar Retiro',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String titulo;
  final String subtitulo;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.titulo,
    required this.subtitulo,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: kTextMain)),
              const SizedBox(height: 2),
              Text(subtitulo,
                  style: const TextStyle(fontSize: 11.5, color: kTextSub)),
            ],
          ),
        ),
        Switch(value: value, activeColor: activeColor, onChanged: onChanged),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: ESTADÍSTICAS (DISEÑO PROFESIONAL RENOVADO)
// ─────────────────────────────────────────────
class EstadisticasPage extends StatefulWidget {
  const EstadisticasPage({super.key});
  @override
  State<EstadisticasPage> createState() => _EstadisticasPageState();
}

class _EstadisticasPageState extends State<EstadisticasPage> {
  bool _cargando = false;
  List<dynamic> _informe = [];
  List<dynamic> _inventario = [];
  String _fechaHoy = '';
  int _touchedIndex = -1;

  static const _iconoTipo = {
    'Plato': Icons.dinner_dining,
    'Vaso': Icons.local_drink_rounded,
    'Taza': Icons.coffee_rounded,
  };

  static const _colorTipo = {
    'Plato': kBlue,
    'Vaso': kAmber,
    'Taza': kPrimary,
  };

  @override
  void initState() {
    super.initState();
    _obtenerEstadisticasHoy();
  }

  Future<void> _obtenerEstadisticasHoy() async {
    setState(() => _cargando = true);
    try {
      final responseInforme = await http.get(Uri.parse('$kBaseUrl/informe'));
      final responseInventario = await http.get(Uri.parse('$kBaseUrl/utensilios'));

      List<dynamic> tempInforme = [];
      List<dynamic> tempInventario = [];

      if (responseInforme.statusCode == 200) {
        final data = jsonDecode(responseInforme.body);
        tempInforme = data is List ? data : (data['informe'] ?? []);
        _fechaHoy = data['fecha'] ?? DateTime.now().toString().split(' ')[0];
      }

      if (responseInventario.statusCode == 200) {
        final dataInv = jsonDecode(responseInventario.body);
        tempInventario = dataInv is List ? dataInv : [];
      }

      setState(() {
        _informe = tempInforme;
        _inventario = tempInventario;
      });
    } catch (_) {
      setState(() {
        _informe = [];
        _inventario = [];
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<BarChartGroupData> _generarBarras() {
    return _informe.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final double entregados = double.tryParse(item['entregados'].toString()) ?? 0.0;
      final tipo = item['tipo'] ?? 'Utensilio';
      final color = _colorTipo[tipo] ?? Colors.blue;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entregados,
            color: color,
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 50,
              color: kBackground,
            ),
          ),
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _generarCircular() {
    double total = _informe.fold(
        0, (s, e) => s + (double.tryParse(e['entregados'].toString()) ?? 0));
    return List.generate(_informe.length, (i) {
      final isTouched = i == _touchedIndex;
      final item = _informe[i];
      final tipo = item['tipo'] ?? 'Utensilio';
      final val = double.tryParse(item['entregados'].toString()) ?? 0.0;
      final pct = total > 0 ? val / total * 100 : 0.0;
      final color = _colorTipo[tipo] ?? kPrimary;

      return PieChartSectionData(
        color: color,
        value: val,
        title: '${pct.toStringAsFixed(0)}%',
        radius: isTouched ? 76.0 : 64.0,
        titleStyle: TextStyle(
          fontSize: isTouched ? 16 : 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 6)],
        ),
        borderSide: isTouched
            ? const BorderSide(color: Colors.white, width: 3)
            : BorderSide.none,
      );
    });
  }

  int get _totalEntregados => _informe.fold(
      0, (s, e) => s + (int.tryParse(e['entregados'].toString()) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Estadísticas del Día', actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _obtenerEstadisticasHoy,
          tooltip: 'Actualizar',
        ),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          if (_fechaHoy.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder),
                  boxShadow: kShadowSoft,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 15, color: kPrimary),
                  const SizedBox(width: 8),
                  Text('Fecha: $_fechaHoy',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kTextMain,
                          fontSize: 13.5)),
                ]),
              ),
            ),

          // Gráfico Circular
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kBorder),
              boxShadow: kShadowSoft,
            ),
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              const Text('Distribución de Vajilla Entregada',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: kTextMain,
                      letterSpacing: -0.2)),
              const SizedBox(height: 22),
              SizedBox(
                height: 230,
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(color: kPrimary))
                    : _informe.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.donut_large_rounded,
                                    size: 48, color: kBorder),
                                const SizedBox(height: 12),
                                const Text('Sin registros para hoy',
                                    style: TextStyle(
                                        color: kTextSub, fontSize: 14)),
                              ],
                            ),
                          )
                        : Stack(children: [
                            PieChart(PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, resp) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        resp == null ||
                                        resp.touchedSection == null) {
                                      _touchedIndex = -1;
                                      return;
                                    }
                                    _touchedIndex = resp.touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 4,
                              centerSpaceRadius: 65,
                              sections: _generarCircular(),
                            )),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$_totalEntregados',
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: kTextMain)),
                                  const Text('Total',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: kTextSub,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ]),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ItemLeyenda(color: kBlue, texto: 'Platos'),
                    _ItemLeyenda(color: kAmber, texto: 'Vasos'),
                    _ItemLeyenda(color: kPrimary, texto: 'Tazas'),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // Gráfico de Barras
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kBorder),
              boxShadow: kShadowSoft,
            ),
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              const Text('Comparativa por Tipo',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: kTextMain,
                      letterSpacing: -0.2)),
              const SizedBox(height: 22),
              SizedBox(
                height: 220,
                child: _cargando
                    ? const Center(child: CircularProgressIndicator(color: kPrimary))
                    : _informe.isEmpty
                        ? const Center(child: Text('Sin datos para gráfica de barras', style: TextStyle(color: kTextSub)))
                        : BarChart(
                            BarChartData(
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      int idx = value.toInt();
                                      if (idx >= 0 && idx < _informe.length) {
                                        String tipo = _informe[idx]['tipo'] ?? '';
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(tipo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: kTextSub)),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                              ),
                              barGroups: _generarBarras(),
                            ),
                          ),
              ),
            ]),
          ),

          const SizedBox(height: 28),
          _sectionTitle('Detalle Profesional por Utensilio'),

          if (_cargando)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else if (_informe.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: const Center(
                  child: Text('Sin movimientos para hoy',
                      style: TextStyle(color: kTextSub))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _informe.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final item = _informe[i];
                final tipo = item['tipo'] ?? 'Utensilio';
                final entregados = item['entregados'] ?? 0;
                final devueltos = item['devueltos'] ?? 0;
                final pendientes = item['pendientes'] ?? 0;
                final col = _colorTipo[tipo] ?? kBlue;

                // Extraer el total inicial del inventario
                final invItem = _inventario.firstWhere(
                  (inv) => (inv['tipo'] ?? '').toString().toLowerCase() == tipo.toString().toLowerCase(),
                  orElse: () => null,
                );
                final cantidadInicial = invItem != null ? (int.tryParse(invItem['cantidad'].toString()) ?? 0) : 0;
                final ocupados = pendientes;

                return Container(
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kBorder, width: 1.2),
                    boxShadow: kShadowSoft,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera del Utensilio
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: col.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_iconoTipo[tipo] ?? Icons.analytics, color: col, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tipo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      color: kTextMain)),
                              const SizedBox(height: 2),
                              const Text('Estado de inventario y flujo diario',
                                  style: TextStyle(fontSize: 12, color: kTextSub)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(color: kBorder, height: 1),
                      const SizedBox(height: 16),
                      
                      // Grid / Fila de Métricas Principales (Diseño Tarjeta Estilizada)
                      Row(
                        children: [
                          Expanded(
                            child: _StatCardPro(
                              label: 'Stock Inicial', 
                              value: '$cantidadInicial', 
                              color: kPrimaryDeep,
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCardPro(
                              label: 'En Préstamo', 
                              value: '$ocupados', 
                              color: kAmber,
                              icon: Icons.hourglass_top_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Desglose Secundario de Actividad (Entregados / Devueltos / Pendientes)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatBadgeDetail(label: 'Entregados', value: '$entregados', color: kBlue),
                            Container(height: 24, width: 1, color: kBorder),
                            _StatBadgeDetail(label: 'Devueltos', value: '$devueltos', color: kGreen),
                            Container(height: 24, width: 1, color: kBorder),
                            _StatBadgeDetail(label: 'Pendientes', value: '$pendientes', color: kPrimary),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }
}

// Tarjeta profesional de métricas principales para los utensilios
class _StatCardPro extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCardPro({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11.5, color: kTextSub, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Insignia de detalle secundario para movimientos
class _StatBadgeDetail extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadgeDetail({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSub)),
      ],
    );
  }
}

class _ItemLeyenda extends StatelessWidget {
  final Color color;
  final String texto;
  const _ItemLeyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 7),
      Text(texto,
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextMain)),
    ]);
  }
}

// ─────────────────────────────────────────────
// PANTALLA: PENDIENTES / DEVOLUCIONES
// ─────────────────────────────────────────────
class PendientesPage extends StatefulWidget {
  const PendientesPage({super.key});
  @override
  State<PendientesPage> createState() => _PendientesPageState();
}

class _PendientesPageState extends State<PendientesPage> {
  final _carnetCtrl = TextEditingController();
  List<dynamic> pendientes = [];
  bool _cargando = false;
  bool _autoDevolucion = true;

  final List<String> _modosSeleccionados = ['Plato', 'Vaso', 'Taza'];
  static const _tiposDisponibles = ['Plato', 'Vaso', 'Taza'];
  static const _iconoTipo = {
    'Plato': Icons.dinner_dining,
    'Vaso': Icons.local_drink_rounded,
    'Taza': Icons.coffee_rounded,
  };
  static const _colorTipo = {
    'Plato': kBlue,
    'Vaso': kAmber,
    'Taza': kPrimary,
  };

  @override
  void dispose() {
    _carnetCtrl.dispose();
    super.dispose();
  }

  void _escanearParaDevolver() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EscaneoPage(
          onCodigoEscaneado: (codigo) {
            setState(() => _carnetCtrl.text = codigo);
            if (_autoDevolucion) {
              _procesarDevolucionMasivaPorEscaneo(codigo);
            } else {
              _consultarPendientesManual();
              mostrarNotificacionApp(
                  'Código Capturado', 'Carnet $codigo capturado.');
            }
          },
        ),
      ),
    );
  }

  Future<void> _consultarPendientesManual() async {
    final carnet = _carnetCtrl.text.trim();
    if (carnet.isEmpty) return;
    setState(() => _cargando = true);
    try {
      final response = await http
          .get(Uri.parse('$kBaseUrl/pendientes/$carnet'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = data is List ? data : (data['pendientes'] ?? []);
        setState(() {
          pendientes = lista;
        });
      } else {
        setState(() => pendientes = []);
        mostrarNotificacionApp('Aviso', 'Sin registros para este carnet',
            esError: false);
      }
    } on SocketException {
      setState(() => pendientes = []);
      mostrarNotificacionApp('Sin Conexión', 'No hay red. Verifica Wi-Fi.', esError: true);
    } catch (_) {
      if (mounted && pendientes.isEmpty) {
        mostrarNotificacionApp('Aviso', 'El servidor tardó en responder. Intenta de nuevo.', esError: false);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _procesarDevolucionMasivaPorEscaneo(String carnet) async {
    if (carnet.isEmpty) return;
    if (_modosSeleccionados.isEmpty) {
      mostrarNotificacionApp(
          'Aviso', 'Selecciona al menos un tipo a devolver',
          esError: true);
      return;
    }
    setState(() => _cargando = true);
    try {
      final response = await http
          .get(Uri.parse('$kBaseUrl/pendientes/$carnet'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        mostrarNotificacionApp('Error', 'Estudiante no encontrado',
            esError: true);
        return;
      }
      final data = jsonDecode(response.body);
      final lista = data is List ? data : (data['pendientes'] ?? []);
      
      if (lista.isEmpty) {
        mostrarNotificacionApp(
            'Aviso', 'Sin préstamos pendientes para este carnet',
            esError: true);
        setState(() => pendientes = []);
        return;
      }

      final aDevolver = lista.where((e) {
        final t = (e['tipo'] ?? '').toString().toLowerCase();
        return _modosSeleccionados.any((m) => m.toLowerCase() == t);
      }).toList();

      if (aDevolver.isEmpty) {
        mostrarNotificacionApp(
            'Aviso', 'Sin pendientes de los tipos seleccionados',
            esError: true);
        setState(() => pendientes = lista);
        return;
      }

      int ok = 0;
      for (final item in aDevolver) {
        final id = item['id'];
        if (id != null) {
          try {
            final r = await http
                .put(Uri.parse('$kBaseUrl/devolucion/$id'))
                .timeout(const Duration(seconds: 10));
            if (r.statusCode == 200 || r.statusCode == 404) ok++;
          } catch (_) {
            ok++;
          }
        }
      }
      if (ok > 0) {
        mostrarNotificacionApp(
            '¡Devolución Exitosa!', 'Se procesaron $ok utensilio(s).');
      }
      await _consultarPendientesManual();
    } on SocketException {
      mostrarNotificacionApp('Sin Conexión', 'No hay red. Verifica Wi-Fi.', esError: true);
    } catch (_) {
      mostrarNotificacionApp(
          'Aviso', 'Respuesta tardía. Verificando estado...',
          esError: false);
      await Future.delayed(const Duration(seconds: 1));
      await _consultarPendientesManual();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _devolverItemIndividual(int movimientoId) async {
    setState(() => _cargando = true);
    try {
      final r = await http
          .put(Uri.parse('$kBaseUrl/devolucion/$movimientoId'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        mostrarNotificacionApp('¡Éxito!', 'Utensilio devuelto correctamente.');
        await _consultarPendientesManual();
      } else if (r.statusCode == 404) {
        mostrarNotificacionApp('Aviso', 'Este ítem ya fue devuelto previamente.');
        await _consultarPendientesManual();
      } else {
        mostrarNotificacionApp('Error', 'No se pudo devolver el ítem (${r.statusCode})', esError: true);
      }
    } on SocketException {
      mostrarNotificacionApp('Sin Conexión', 'No hay red. Verifica tu conexión Wi-Fi.', esError: true);
    } catch (_) {
      mostrarNotificacionApp('Aviso', 'Respuesta tardía. Verificando estado...', esError: false);
      await Future.delayed(const Duration(seconds: 1));
      await _consultarPendientesManual();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Pendientes y Devoluciones'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _sectionTitle('1. Filtrar por Tipo de Utensilio'),
          Row(
            children: _tiposDisponibles.map((tipo) {
              final sel = _modosSeleccionados.contains(tipo);
              final col = _colorTipo[tipo] ?? kPrimary;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (sel) {
                      if (_modosSeleccionados.length > 1) {
                        _modosSeleccionados.remove(tipo);
                      }
                    } else {
                      _modosSeleccionados.add(tipo);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 6),
                    decoration: BoxDecoration(
                      color: sel ? col : kSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: sel ? col : kBorder, width: 1.5),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                  color: col.withOpacity(0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]
                          : kShadowSoft,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconoTipo[tipo],
                            color: sel ? Colors.white : col, size: 24),
                        const SizedBox(height: 6),
                        Text(tipo,
                            style: TextStyle(
                                color: sel ? Colors.white : kTextSub,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5)),
                        const SizedBox(height: 5),
                        Icon(
                          sel
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color:
                              sel ? Colors.white70 : const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          _ToggleRow(
            icon: _autoDevolucion
                ? Icons.bolt_rounded
                : Icons.touch_app_rounded,
            iconColor: _autoDevolucion ? kGreen : kTextSub,
            titulo: 'Devolución automática al escanear',
            subtitulo: _autoDevolucion
                ? 'Devuelve al instante al escanear'
                : 'Muestra lista para devolución manual',
            value: _autoDevolucion,
            activeColor: kGreen,
            onChanged: (v) => setState(() => _autoDevolucion = v),
          ),

          const SizedBox(height: 16),
          _sectionTitle('2. Carnet del alumno'),

          TextField(
            controller: _carnetCtrl,
            decoration: InputDecoration(
              labelText: 'Carnet del Alumno',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    color: kPrimary, size: 26),
                onPressed: _escanearParaDevolver,
                tooltip: 'Escanear carnet',
              ),
            ),
            onSubmitted: (_) => _consultarPendientesManual(),
          ),

          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryDeep,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _consultarPendientesManual,
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text('Consultar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _escanearParaDevolver,
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text('Escanear',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),

          const SizedBox(height: 20),
          _sectionTitle('Lista de Pendientes (Debe)'),

          Expanded(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimary))
                : _carnetCtrl.text.trim().isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined,
                                size: 52, color: kBorder),
                            const SizedBox(height: 12),
                            const Text(
                              'Ingresa o escanea un carnet para ver qué debe',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: kTextSub, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : Builder(builder: (context) {
                        final filtrados = pendientes.where((e) {
                          final t = (e['tipo'] ?? '').toString().toLowerCase();
                          return _modosSeleccionados
                              .any((m) => m.toLowerCase() == t);
                        }).toList();

                        if (filtrados.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: kGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.check_circle_rounded,
                                      color: kGreen,
                                      size: 36),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Sin pendientes para el tipo seleccionado',
                                  style: TextStyle(
                                      color: kGreen,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final item = filtrados[i];
                              final idMov = item['id'];
                              final tipo = item['tipo'] ?? 'Utensilio';
                              final fecha = item['fecha_retiro'] ?? '';
                              final col = _colorTipo[tipo] ?? kBlue;

                              return Container(
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kBorder),
                                  boxShadow: kShadowSoft,
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: col.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                        _iconoTipo[tipo] ??
                                            Icons.restaurant,
                                        color: col,
                                        size: 22),
                                  ),
                                  title: Text(tipo,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: kTextMain)),
                                  subtitle: Text(
                                      'Retirado: $fecha',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: kTextSub)),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kGreen,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onPressed: idMov != null
                                        ? () => _devolverItemIndividual(idMov)
                                        : null,
                                    child: const Text('Devolver',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            },
                          );
                      }),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: REGISTRAR ESTUDIANTE
// ─────────────────────────────────────────────
class RegistrarEstudiantePage extends StatefulWidget {
  final String codigoInicial;
  const RegistrarEstudiantePage({super.key, this.codigoInicial = ''});
  @override
  State<RegistrarEstudiantePage> createState() =>
      _RegistrarEstudiantePageState();
}

class _RegistrarEstudiantePageState
    extends State<RegistrarEstudiantePage> {
  late final TextEditingController _codigoCtrl;
  final _nombreCtrl = TextEditingController();
  final _carnetCtrl = TextEditingController();
  final _gradoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _codigoCtrl = TextEditingController(text: widget.codigoInicial);
    _carnetCtrl.text = widget.codigoInicial;
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _carnetCtrl.dispose();
    _gradoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarEstudiante() async {
    if (_nombreCtrl.text.trim().isEmpty ||
        _carnetCtrl.text.trim().isEmpty ||
        _codigoCtrl.text.trim().isEmpty) {
      mostrarNotificacionApp(
          'Aviso', 'Completa todos los campos obligatorios',
          esError: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      final resp = await http.post(
        Uri.parse('$kBaseUrl/estudiante'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': _nombreCtrl.text.trim(),
          'carnet': _carnetCtrl.text.trim(),
          'codigo_barra': _codigoCtrl.text.trim(),
          'grado': _gradoCtrl.text.trim(),
        }),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        mostrarNotificacionApp('Éxito', 'Estudiante registrado');
        if (mounted) Navigator.pop(context);
      } else {
        mostrarNotificacionApp('Error', 'Error al guardar en el servidor',
            esError: true);
      }
    } catch (_) {
      mostrarNotificacionApp(
          'Error de Red', 'No se pudo conectar al servidor',
          esError: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Registrar Nuevo Estudiante'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kBorder),
            boxShadow: kShadowSoft,
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: kPrimary, size: 22),
                ),
                const SizedBox(width: 14),
                const Text('Información del Alumno',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kTextMain)),
              ]),
              const SizedBox(height: 20),
              const Divider(color: kBorder, height: 1),
              const SizedBox(height: 20),
              _buildField(_nombreCtrl, 'Nombre completo',
                  Icons.person_outline),
              const SizedBox(height: 14),
              _buildField(_carnetCtrl, 'Número de Carnet',
                  Icons.badge_outlined),
              const SizedBox(height: 14),
              _buildField(_codigoCtrl, 'Código de barras',
                  Icons.qr_code_rounded),
              const SizedBox(height: 14),
              _buildField(_gradoCtrl,
                  'Grado / Sección (Ej: 2° Software)',
                  Icons.school_outlined),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _guardando ? null : _guardarEstudiante,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.save_rounded),
                  label: Text(
                      _guardando
                          ? 'Guardando...'
                          : 'Guardar Estudiante',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: INFORMES HISTÓRICOS
// ─────────────────────────────────────────────
class InformesPage extends StatefulWidget {
  const InformesPage({super.key});
  @override
  State<InformesPage> createState() => _InformesPageState();
}

class _InformesPageState extends State<InformesPage> {
  final _fechaController = TextEditingController();
  bool _cargando = false;
  List<dynamic> _informe = [];

  static const _iconoTipo = {
    'Plato': Icons.dinner_dining,
    'Vaso': Icons.local_drink_rounded,
    'Taza': Icons.coffee_rounded,
  };
  static const _colorTipo = {
    'Plato': kBlue,
    'Vaso': kAmber,
    'Taza': kPrimary,
  };

  @override
  void initState() {
    super.initState();
    _fechaController.text = DateTime.now().toString().split(' ')[0];
  }

  @override
  void dispose() {
    _fechaController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _fechaController.text = picked.toIso8601String().split('T')[0];
      });
      _obtenerInformeHistorico();
    }
  }

  Future<void> _obtenerInformeHistorico() async {
    final fecha = _fechaController.text.trim();
    if (fecha.isEmpty) return;
    setState(() => _cargando = true);
    try {
      final response =
          await http.get(Uri.parse('$kBaseUrl/informe/$fecha'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _informe = data is List ? data : (data['informe'] ?? []);
        });
      } else {
        setState(() => _informe = []);
      }
    } catch (_) {
      setState(() => _informe = []);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _exportarPDF() async {
    if (_informe.isEmpty) return;
    final pdf = pw.Document();
    final fecha = _fechaController.text;
    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Informe Diario — Cocina Escolar INFRAMEN',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Fecha del reporte: $fecha',
                style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Utensilio',
                'Entregados',
                'Devueltos',
                'Pendientes'
              ],
              data: _informe
                  .map((e) => [
                        e['tipo'].toString(),
                        e['entregados'].toString(),
                        (e['devueltos'] ?? 0).toString(),
                        (e['pendientes'] ?? 0).toString(),
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'informe_cocina_$fecha.pdf',
    );
  }

  Future<void> _exportarExcel() async {
    if (_informe.isEmpty) return;
    try {
      var ex = excel_pkg.Excel.createExcel();
      excel_pkg.Sheet sheet = ex['Informe'];
      ex.setDefaultSheet('Informe');
      sheet.appendRow([
        excel_pkg.TextCellValue('Utensilio'),
        excel_pkg.TextCellValue('Entregados'),
        excel_pkg.TextCellValue('Devueltos'),
        excel_pkg.TextCellValue('Pendientes'),
      ]);
      for (final item in _informe) {
        sheet.appendRow([
          excel_pkg.TextCellValue(item['tipo'].toString()),
          excel_pkg.IntCellValue(
              int.tryParse(item['entregados'].toString()) ?? 0),
          excel_pkg.IntCellValue(
              int.tryParse((item['devueltos'] ?? 0).toString()) ?? 0),
          excel_pkg.IntCellValue(
              int.tryParse((item['pendientes'] ?? 0).toString()) ?? 0),
        ]);
      }
      final bytes = ex.save();
      if (bytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/informe_cocina_${_fechaController.text}.xlsx';
        await File(path).writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        mostrarNotificacionApp(
            'Archivo Guardado', 'Excel guardado correctamente');
        OpenFile.open(path);
      }
    } catch (e) {
      if (!mounted) return;
      mostrarNotificacionApp('Error', 'Error al exportar Excel: $e',
          esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Exportación de Informes'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorder),
              boxShadow: kShadowSoft,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selecciona la fecha',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: kTextSub)),
                const SizedBox(height: 12),
                TextField(
                  controller: _fechaController,
                  decoration: InputDecoration(
                    labelText: 'Fecha (YYYY-MM-DD)',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.event_note_rounded,
                          color: kPrimary),
                      onPressed: () => _seleccionarFecha(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _cargando ? null : _obtenerInformeHistorico,
                    icon: _cargando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.search_rounded),
                    label: Text(
                        _cargando ? 'Buscando...' : 'Obtener Informe',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _informe.isEmpty ? null : _exportarPDF,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _informe.isEmpty ? null : _exportarExcel,
                icon: const Icon(Icons.table_chart_rounded),
                label: const Text('Excel',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),

          const SizedBox(height: 20),
          _sectionTitle('Resultado del Informe'),

          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _informe.isEmpty
                    ? const Center(
                        child: Text('Sin datos para la fecha seleccionada',
                            style: TextStyle(color: kTextSub)))
                    : ListView.separated(
                        itemCount: _informe.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = _informe[i];
                          final tipo = item['tipo'] ?? 'Utensilio';
                          final entregados = item['entregados'] ?? 0;
                          final devueltos = item['devueltos'] ?? 0;
                          final pendientes = item['pendientes'] ?? 0;
                          final col = _colorTipo[tipo] ?? kBlue;

                          return Container(
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: kBorder),
                              boxShadow: kShadowSoft,
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: col.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_iconoTipo[tipo] ?? Icons.analytics,
                                    color: col, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tipo,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: kTextMain)),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      _Stat(
                                          label: 'Entregados',
                                          value: '$entregados',
                                          color: kBlue),
                                      const SizedBox(width: 14),
                                      _Stat(
                                          label: 'Devueltos',
                                          value: '$devueltos',
                                          color: kGreen),
                                      const SizedBox(width: 14),
                                      _Stat(
                                          label: 'Pendientes',
                                          value: '$pendientes',
                                          color: kPrimary),
                                    ]),
                                  ],
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: ESCANEO DE CÓDIGOS DE BARRAS
// ─────────────────────────────────────────────
class EscaneoPage extends StatefulWidget {
  final ValueChanged<String> onCodigoEscaneado;
  const EscaneoPage({super.key, required this.onCodigoEscaneado});

  @override
  State<EscaneoPage> createState() => _EscaneoPageState();
}

class _EscaneoPageState extends State<EscaneoPage>
    with SingleTickerProviderStateMixin {
  bool _encontrado = false;
  late MobileScannerController cameraController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      cameraController.stop();
    }
    cameraController.start();
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar('Escanear Código de Barras'),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_encontrado) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _encontrado = true;
                  widget.onCodigoEscaneado(barcode.rawValue!);
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 320,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    border: Border.all(color: kPrimary, width: 2.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            top: _animationController.value * 130 + 8,
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: kPrimary,
                                boxShadow: [
                                  BoxShadow(
                                    color: kPrimary.withOpacity(0.8),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Alinea el código de barras dentro del rectángulo',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
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
