import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'nearby_screen.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  static const types = ['Medical', 'Fire', 'Accident', 'Other'];
  static const severities = ['Critical', 'Serious', 'Moderate'];

  String _type = 'Medical';
  String _severity = 'Critical';

  Widget _chips(
      List<String> items, String selected, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item),
            selected: item == selected,
            selectedColor: AppColors.red,
            labelStyle: TextStyle(
              color: item == selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            checkmarkColor: Colors.white,
            onSelected: (_) => onPick(item),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Route')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Emergency Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _chips(types, _type, (v) => setState(() => _type = v)),
          const SizedBox(height: 28),
          const Text('Severity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _chips(severities, _severity, (v) => setState(() => _severity = v)),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NearbyScreen(type: _type, severity: _severity),
                ),
              );
            },
            child: const Text('FIND BEST ROUTE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}