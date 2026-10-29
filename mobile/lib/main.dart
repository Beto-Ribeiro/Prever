import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controles/controle_acessibilidade.dart';
import 'telas/exportador_import.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv.load() DEVE ser chamado antes de qualquer acesso a dotenv.env
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  // Inicializa o Firebase (necessário para o Nimbo — chatbot IA)
  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  if (firebaseOptions.apiKey.isNotEmpty) {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AccessibilityController(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    return MaterialApp(
      title: 'SMDN App',
      debugShowCheckedModeBanner: false,

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              acessibilidade.escalaFonte,
            ),
          ),
          child: child!,
        );
      },

      theme: ThemeData(
        scaffoldBackgroundColor: acessibilidade.fundo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: acessibilidade.corPrimaria,
          primary: acessibilidade.corPrimaria,
          secondary: acessibilidade.corSecundaria,
          brightness: acessibilidade.altoContraste
              ? Brightness.dark
              : Brightness.light,
        ),
        useMaterial3: true,
      ),

      home: const TelaPrincipal(),
    );
  }
}
