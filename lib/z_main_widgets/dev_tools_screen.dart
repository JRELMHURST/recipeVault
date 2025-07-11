import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DevToolsScreen extends StatefulWidget {
  const DevToolsScreen({super.key});

  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  bool _isLoading = false;
  String? _resultMessage;

  Future<void> _setSuperUser() async {
    setState(() {
      _isLoading = true;
      _resultMessage = null;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('setSuperUser')
          .call({'email': 'jnriggall@gmail.com'});

      setState(() {
        _resultMessage = '✅ Success: ${result.data}';
      });
    } catch (e) {
      setState(() {
        _resultMessage = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              Text('Logged in as: ${user.email}'),
              const SizedBox(height: 8),
              Text('UID: ${user.uid}'),
            ],
            const Divider(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _setSuperUser,
              child: const Text('Set jnriggall@gmail.com as Super User'),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_resultMessage != null)
              Text(
                _resultMessage!,
                style: TextStyle(
                  color: _resultMessage!.contains('Success')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
