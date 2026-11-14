import 'package:flutter/material.dart';
import '../lab/lab_screen.dart';
import '../theme/app_theme.dart';
import 'emergency_info_screen.dart';
import 'emergency_screen.dart';
import 'nearby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_Action>[
      _Action(Icons.local_hospital, 'Emergency Route',
          (_) => const EmergencyScreen()),
      _Action(Icons.local_pharmacy, 'Find Hospital',
          (_) => const NearbyScreen(type: 'Medical', severity: 'Moderate')),
      _Action(Icons.alt_route, 'Safe Route', (_) => const LabScreen()),
      _Action(Icons.assignment, 'Emergency Info',
          (_) => const EmergencyInfoScreen()),
    ];

    return Scaffold(
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                for (final a in actions)
                  _ActionCard(
                    action: a,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: a.builder),
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

class _Action {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  _Action(this.icon, this.label, this.builder);
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.red, AppColors.darkRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: const Column(
        children: [
          Icon(Icons.sos, color: Colors.white, size: 56),
          SizedBox(height: 8),
          Text(
            'ResQ AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Intelligent Emergency Assistant',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _Action action;
  final VoidCallback onTap;

  const _ActionCard({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, size: 44, color: AppColors.red),
            const SizedBox(height: 12),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}