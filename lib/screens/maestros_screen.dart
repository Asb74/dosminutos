import 'package:flutter/material.dart';

class MaestrosScreen extends StatelessWidget {
  const MaestrosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maestros'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _MaestroCard(
              title: 'Equipos',
              description: 'Crea y administra equipos.',
              icon: Icons.groups,
              colorScheme: colorScheme,
              onTap: () => Navigator.pushNamed(context, '/equipos'),
            ),
            _MaestroCard(
              title: 'Jugadores',
              description: 'Gestión de jugadores (próximamente).',
              icon: Icons.person,
              colorScheme: colorScheme,
              onTap: () {},
            ),
            _MaestroCard(
              title: 'Árbitros',
              description: 'Gestión de árbitros (próximamente).',
              icon: Icons.sports,
              colorScheme: colorScheme,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _MaestroCard extends StatelessWidget {
  const _MaestroCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.colorScheme,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.18),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: Icon(icon),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
