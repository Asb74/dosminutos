import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _navigateTo(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dos Minutos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _HomeCard(
              title: 'Nuevo partido',
              subtitle: 'Configura un partido nuevo.',
              icon: Icons.sports_handball,
              colorScheme: colorScheme,
              onTap: () => _navigateTo(context, '/nuevoPartido'),
            ),
            _HomeCard(
              title: 'Historial',
              subtitle: 'Consulta partidos previos.',
              icon: Icons.history,
              colorScheme: colorScheme,
              onTap: () => _navigateTo(context, '/historial'),
            ),
            _HomeCard(
              title: 'Partidos',
              subtitle: 'Ver y continuar partidos.',
              icon: Icons.sports,
              colorScheme: colorScheme,
              onTap: () => _navigateTo(context, '/partidos'),
            ),
            _HomeCard(
              title: 'Maestros',
              subtitle: 'Gestiona catálogos y datos base.',
              icon: Icons.settings,
              colorScheme: colorScheme,
              onTap: () => _navigateTo(context, '/maestros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorScheme,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
              subtitle,
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
