
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controles/controle_acessibilidade.dart';
import 'telas/exportador_import.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv.load() DEVE ser chamado antes de qualquer acesso a dotenv.env
  await dotenv.load(fileName: ".env");

  // Inicializa o Firebase (necessário para o Nimbo — chatbot IA)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'https://robfgvtnoooivihlnomr.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_eVCeoqzfhoAgkpBnJxzs7w_-PGO0TO9',
  );

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
