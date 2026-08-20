import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouteNotFound extends StatelessWidget {
  const RouteNotFound({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No screen matches $location', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
