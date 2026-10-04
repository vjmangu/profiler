import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState()..init();
  runApp(ProfilerApp(state: state));
}

class ProfilerApp extends StatelessWidget {
  const ProfilerApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4F46E5);
    return MaterialApp(
      title: 'Profiler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!state.hasPin) {
            return PinSetupScreen(onDone: state.setPin);
          }
          return HomeScreen(state: state);
        },
      ),
    );
  }
}
