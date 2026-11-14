import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class EmergencyInfoScreen extends StatelessWidget {
  const EmergencyInfoScreen({super.key});

  static const _numbers = [
    ['112', 'National Emergency', 'Police, fire and ambulance, all India'],
    ['108', 'Ambulance', 'Free emergency medical service'],
    ['101', 'Fire', 'Fire and rescue'],
    ['100', 'Police', 'Police control room'],
    ['181', 'Women Helpline', 'Help for women in distress'],
    ['1098', 'Childline', 'Help for children in need'],
  ];

  Future<void> _call(BuildContext context, String number) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tap a number to open the dialer.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          for (final n in _numbers)
            Card(
              color: Colors.white,
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.red,
                  child: const Icon(Icons.call, color: Colors.white),
                ),
                title: Text(
                  '${n[0]}  ${n[1]}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(n[2]),
                onTap: () => _call(context, n[0]),
              ),
            ),
        ],
      ),
    );
  }
}