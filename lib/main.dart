import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/music_provider.dart';
import 'screens/music_library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final musicProvider = MusicProvider();
  await musicProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: musicProvider,
      child: const MusicPlayerApp(),
    ),
  );
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MusicLibraryScreen(),
    );
  }
}
