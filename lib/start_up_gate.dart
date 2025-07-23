import 'package:flutter/material.dart';
import 'services/user_session_service.dart';

class StartupGate extends StatelessWidget {
  final Widget child;

  const StartupGate({super.key, required this.child});

  /// Initialises user session and subscription state
  Future<void> _initialise() async {
    await UserSessionService.init(); // Firestore sync + RC login + subscription refresh
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialise(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        return child;
      },
    );
  }
}
