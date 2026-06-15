import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sensor_data.dart';
import '../../providers/app_provider.dart';
import '../../widgets/sensor_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final data = provider.sensorData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Plant Monitor'),
        actions: [
          if (data != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'Updated ${_relativeTime(data.lastUpdated)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? _NoDataView()
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PumpControlCard(data: data, provider: provider),
                        const SizedBox(height: 20),
                        Text(
                          'Sensor Readings',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _SensorGrid(data: data),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt);
  }
}

class _PumpControlCard extends StatelessWidget {
  final SensorData data;
  final AppProvider provider;

  const _PumpControlCard({required this.data, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isOn  = data.pumpRunning;
    final cmd   = provider.pumpCommand; // "on" | "off" | "auto"
    final color = Theme.of(context).colorScheme;

    // LED is green when pump is physically running OR command is "on"
    final ledOn = isOn || cmd == 'on';

    return Card(
      color: ledOn ? color.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop_rounded,
                  color: ledOn ? color.primary : Colors.grey,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water Pump',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        cmd == 'auto'
                            ? (isOn ? 'Auto — Running' : 'Auto — Idle')
                            : cmd == 'on'
                                ? 'Manually ON'
                                : 'Manually OFF',
                        style: TextStyle(
                          color: ledOn ? color.primary : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _PumpStatusDot(running: ledOn),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _PumpBtn(
                  label: 'ON',
                  icon: Icons.play_arrow_rounded,
                  selected: cmd == 'on',
                  color: color.primary,
                  onTap: () => provider.setPump('on'),
                ),
                const SizedBox(width: 8),
                _PumpBtn(
                  label: 'OFF',
                  icon: Icons.stop_rounded,
                  selected: cmd == 'off',
                  color: Colors.red,
                  onTap: () => provider.setPump('off'),
                ),
                const SizedBox(width: 8),
                _PumpBtn(
                  label: 'Auto',
                  icon: Icons.auto_mode_rounded,
                  selected: cmd == 'auto',
                  color: Colors.green,
                  onTap: () => provider.setPump('auto'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PumpBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: color.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
    );
  }
}

class _PumpStatusDot extends StatefulWidget {
  final bool running;
  const _PumpStatusDot({required this.running});

  @override
  State<_PumpStatusDot> createState() => _PumpStatusDotState();
}

class _PumpStatusDotState extends State<_PumpStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.running) {
      return const CircleAvatar(radius: 7, backgroundColor: Colors.grey);
    }
    return FadeTransition(
      opacity: _anim,
      child: const CircleAvatar(radius: 7, backgroundColor: Colors.green),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  final SensorData data;
  const _SensorGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards(data);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => cards[i],
    );
  }

  List<Widget> _buildCards(SensorData d) {
    String soilStatus = d.soilMoisturePct < 30
        ? 'DRY'
        : d.soilMoisturePct < 60
            ? 'OK'
            : 'WET';
    Color soilColor = d.soilMoisturePct < 30
        ? Colors.orange
        : d.soilMoisturePct < 60
            ? Colors.green
            : Colors.blue;

    String waterStatus = d.waterLevelCm < 5
        ? 'LOW'
        : d.waterLevelCm < 10
            ? 'MED'
            : 'FULL';
    Color waterColor =
        d.waterLevelCm < 5 ? Colors.red : d.waterLevelCm < 10 ? Colors.orange : Colors.blue;

    String lightStatus =
        d.lightLux < 200 ? 'LOW' : d.lightLux < 1000 ? 'OK' : 'BRIGHT';
    Color lightColor =
        d.lightLux < 200 ? Colors.orange : d.lightLux < 1000 ? Colors.green : Colors.amber;

    return [
      SensorCard(
        label: 'Soil Moisture',
        value: d.soilMoisturePct.toStringAsFixed(1),
        unit: '%',
        icon: Icons.water_drop_outlined,
        iconColor: Colors.blue,
        bgColor: Colors.blue.shade50,
        progressValue: d.soilMoisturePct / 100,
        statusLabel: soilStatus,
        statusColor: soilColor,
      ),
      SensorCard(
        label: 'Air Temperature',
        value: d.airTempC.toStringAsFixed(1),
        unit: '°C',
        icon: Icons.thermostat_rounded,
        iconColor: Colors.orange,
        bgColor: Colors.orange.shade50,
        statusLabel: d.airTempC > 35 ? 'HOT' : 'OK',
        statusColor: d.airTempC > 35 ? Colors.red : Colors.green,
      ),
      SensorCard(
        label: 'Humidity',
        value: d.humidityPct.toStringAsFixed(1),
        unit: '%',
        icon: Icons.cloud_rounded,
        iconColor: Colors.teal,
        bgColor: Colors.teal.shade50,
        progressValue: d.humidityPct / 100,
      ),
      SensorCard(
        label: 'Light Intensity',
        value: d.lightLux.toStringAsFixed(0),
        unit: 'lux',
        icon: Icons.wb_sunny_rounded,
        iconColor: Colors.amber,
        bgColor: Colors.amber.shade50,
        statusLabel: lightStatus,
        statusColor: lightColor,
      ),
      SensorCard(
        label: 'Water Level',
        value: d.waterLevelCm.toStringAsFixed(1),
        unit: 'cm',
        icon: Icons.water_rounded,
        iconColor: Colors.blue.shade700,
        bgColor: Colors.blue.shade100,
        progressValue: d.waterLevelCm / 25, // max tank 25cm
        statusLabel: waterStatus,
        statusColor: waterColor,
      ),
      SensorCard(
        label: 'Soil Temperature',
        value: d.soilTempC.toStringAsFixed(1),
        unit: '°C',
        icon: Icons.device_thermostat_rounded,
        iconColor: Colors.brown,
        bgColor: Colors.brown.shade50,
      ),
    ];
  }
}

class _NoDataView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No sensor data yet'),
          const SizedBox(height: 8),
          Text(
            'Waiting for ESP32 to connect…',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
