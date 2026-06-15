import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  String _email = '';
  bool _loadingProfile = true;

  double _soilDry  = 30.0;
  double _waterLow = 5.0;
  double _tempHigh = 35.0;

  // calibration state
  double? _calibratedHeight;
  bool _calibrating = false;
  String _calibStatus = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _listenCalibration();
  }

  Future<void> _loadAll() async {
    final user    = FirebaseAuth.instance.currentUser;
    final profile = await DatabaseService.instance.getUserProfile();
    final thresh  = await DatabaseService.instance.getThresholds();
    if (mounted) {
      setState(() {
        _name     = profile?['name'] as String? ?? user?.displayName ?? '';
        _email    = user?.email ?? '';
        _soilDry  = thresh['soilDry']  as double;
        _waterLow = thresh['waterLow'] as double;
        _tempHigh = thresh['tempHigh'] as double;
        _loadingProfile = false;
      });
    }
  }

  void _listenCalibration() {
    DatabaseService.instance.calibrationStream().listen((data) {
      if (data == null || !mounted) return;
      final height   = (data['tankHeightCm'] as num?)?.toDouble();
      final inProg   = data['calibrateNow'] as bool? ?? false;
      setState(() {
        _calibratedHeight = height;
        if (inProg) {
          _calibrating = true;
          _calibStatus = 'Waiting for ESP32 to measure…';
        } else if (height != null && _calibrating) {
          _calibrating = false;
          _calibStatus = 'Calibrated! Tank height = ${height.toStringAsFixed(1)} cm';
        }
      });
    });
  }

  Future<void> _editName() async {
    final ctrl   = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await DatabaseService.instance.updateUserName(result);
      await FirebaseAuth.instance.currentUser?.updateDisplayName(result);
      if (mounted) setState(() => _name = result);
    }
  }

  Future<void> _editThreshold({
    required String title,
    required String unit,
    required double current,
    required double min,
    required double max,
    required String key,
  }) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(1));
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: InputDecoration(
            labelText: 'Value',
            suffixText: unit,
            helperText: 'Range: $min – $max $unit',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val >= min && val <= max) {
                Navigator.pop(context, val);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await DatabaseService.instance.updateThreshold(key, result);
      setState(() {
        if (key == 'soilDry')  _soilDry  = result;
        if (key == 'waterLow') _waterLow = result;
        if (key == 'tempHigh') _tempHigh = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title updated to ${result.toStringAsFixed(1)} $unit')),
        );
      }
    }
  }

  Future<void> _startCalibration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Calibrate Water Tank'),
        content: const Text(
          'Make sure your water tank is EMPTY before calibrating.\n\n'
          'The ESP32 will measure the distance from the sensor to the bottom '
          'of the tank and save it as the tank height.\n\n'
          'Is the tank empty?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, calibrate now'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _calibrating = true;
        _calibStatus = 'Sending calibration command…';
      });
      await DatabaseService.instance.triggerCalibration();
      if (mounted) {
        setState(() => _calibStatus = 'Waiting for ESP32 to measure…');
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AppProvider>().stopListening();
      await AuthService.instance.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Profile ──────────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: color.primaryContainer,
                          child: Text(
                            _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: color.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_name,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(_email,
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _editName),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Tank Calibration ──────────────────────────────────────
                _sectionTitle(context, 'Water Tank Calibration'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.water_rounded, color: color.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tank Height',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    _calibratedHeight != null
                                        ? '${_calibratedHeight!.toStringAsFixed(1)} cm (calibrated)'
                                        : 'Not calibrated yet',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_calibStatus.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _calibrating
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (_calibrating)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                else
                                  const Icon(Icons.check_circle,
                                      size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_calibStatus,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Empty the tank completely, then tap Calibrate. '
                          'The ESP32 will measure the sensor-to-bottom distance '
                          'and use it as the full tank height automatically.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _calibrating ? null : _startCalibration,
                            icon: _calibrating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.straighten_rounded),
                            label: Text(_calibrating
                                ? 'Calibrating…'
                                : 'Calibrate Empty Tank'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Thresholds ────────────────────────────────────────────
                _sectionTitle(context, 'Thresholds & Alerts'),
                Card(
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.water_drop_rounded,
                        title: 'Low Soil Moisture Alert',
                        subtitle: 'Trigger below ${_soilDry.toStringAsFixed(0)}%',
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _editThreshold(
                          title: 'Low Soil Moisture',
                          unit: '%',
                          current: _soilDry,
                          min: 5,
                          max: 80,
                          key: 'soilDry',
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _tile(
                        icon: Icons.water_rounded,
                        title: 'Low Water Level Alert',
                        subtitle: 'Trigger below ${_waterLow.toStringAsFixed(0)} cm',
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _editThreshold(
                          title: 'Low Water Level',
                          unit: 'cm',
                          current: _waterLow,
                          min: 1,
                          max: 20,
                          key: 'waterLow',
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _tile(
                        icon: Icons.thermostat_rounded,
                        title: 'High Temperature Alert',
                        subtitle: 'Trigger above ${_tempHigh.toStringAsFixed(0)}°C',
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _editThreshold(
                          title: 'High Temperature',
                          unit: '°C',
                          current: _tempHigh,
                          min: 20,
                          max: 50,
                          key: 'tempHigh',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Device ────────────────────────────────────────────────
                _sectionTitle(context, 'Device'),
                Card(
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.wifi_rounded,
                        title: 'ESP32 Connection',
                        subtitle: 'Connected via Firebase RTDB',
                        trailing: const Icon(Icons.check_circle_rounded,
                            color: Colors.green),
                      ),
                      const Divider(height: 1, indent: 56),
                      _tile(
                        icon: Icons.sensors_rounded,
                        title: 'Sensor Update Interval',
                        subtitle: 'Every 30 seconds',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Account ───────────────────────────────────────────────
                _sectionTitle(context, 'Account'),
                Card(
                  child: Column(
                    children: [
                      _tile(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        onTap: () async {
                          await AuthService.instance.resetPassword(_email);
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reset email sent!')),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      _tile(
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        iconColor: Colors.red,
                        textColor: Colors.red,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Smart Plant Monitor v1.0.0',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.primary,
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: textColor)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing,
        onTap: onTap,
      );
}
