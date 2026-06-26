import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sensor_data.dart';
import '../../providers/app_provider.dart';
import '../../widgets/sensor_card.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kHeroBg       = Color(0xFF0B1F10);
const _kHeroCard     = Color(0xFF142C1A);
const _kHeroBorder   = Color(0xFF1E4025);
const _kGreen        = Color(0xFF22C55E);
const _kGreenDark    = Color(0xFF16A34A);
const _kRed          = Color(0xFFEF4444);
const _kAmber        = Color(0xFFF59E0B);
const _kBlue         = Color(0xFF3B82F6);
const _kCyan         = Color(0xFF06B6D4);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final data = provider.sensorData;

    return Scaffold(
      backgroundColor: Colors.white,
      body: provider.loading
          ? const _LoadingView()
          : data == null
              ? const _NoDataView()
              : _DashboardBody(data: data, provider: provider),
    );
  }
}

// ── Main body ──────────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final SensorData data;
  final AppProvider provider;

  const _DashboardBody({required this.data, required this.provider});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final unread = provider.unreadCount;

    return CustomScrollView(
      slivers: [

        // ── Hero (dark green) ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: _kHeroBg,
            padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // App bar row
                Row(
                  children: [
                    _AppLogoChip(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Smart Plant Monitor',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                          Row(
                            children: [
                              Container(
                                width: 5, height: 5,
                                decoration: const BoxDecoration(
                                  color: _kGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text('Updated ${_relativeTime(data.lastUpdated)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 11,
                                )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Notification bell
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.notifications_outlined,
                            color: Colors.white70, size: 20),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(
                                color: _kGreen, shape: BoxShape.circle),
                              child: Center(
                                child: Text('$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Greeting + plant emoji
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting,
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 13,
                          )),
                        Row(
                          children: [
                            Text('Teebak',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                height: 1.2,
                              )),
                            const SizedBox(width: 8),
                            const Text('🌿', style: TextStyle(fontSize: 22)),
                          ],
                        ),
                        Text("Here's your plant system overview",
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 12,
                          )),
                        const SizedBox(height: 100),
                      ],
                    ),
                    // Plant pot illustration
                    Positioned(
                      right: -8, top: -12,
                      child: Text('🪴',
                        style: const TextStyle(fontSize: 96),
                      ),
                    ),
                  ],
                ),

                // Pump card
                _PumpCard(data: data, provider: provider),
              ],
            ),
          ),
        ),

        // ── Section header ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sensor Readings',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  )),
                _AllGoodBadge(data: data),
              ],
            ),
          ),
        ),

        // ── Sensor grid ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate(_sensorCards(data)),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
          ),
        ),

        // ── System Health ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: _SystemHealthCard(data: data),
          ),
        ),
      ],
    );
  }

  List<Widget> _sensorCards(SensorData d) {
    final soilStatus = d.soilMoisturePct < 30 ? 'DRY' : d.soilMoisturePct > 60 ? 'WET' : 'OK';
    final soilColor = d.soilMoisturePct < 30 ? _kRed : d.soilMoisturePct > 60 ? _kBlue : _kGreenDark;

    final tempStatus = d.airTempC > 35 ? 'HOT' : d.airTempC > 32 ? 'WARM' : 'OK';
    final tempColor = d.airTempC > 35 ? _kRed : d.airTempC > 32 ? _kAmber : _kGreenDark;

    final humStatus = d.humidityPct < 40 ? 'DRY' : d.humidityPct > 70 ? 'HIGH' : 'OK';
    final humColor = d.humidityPct < 40 ? _kRed : d.humidityPct > 70 ? _kBlue : _kGreenDark;

    final lightStatus = d.lightLux < 50 ? 'DARK' : d.lightLux < 250 ? 'OK' : d.lightLux < 1000 ? 'BRIGHT' : 'INTENSE';
    final lightColor = d.lightLux < 50 ? const Color(0xFF6B7280) : d.lightLux < 250 ? _kGreenDark : d.lightLux < 1000 ? _kAmber : _kRed;

    final waterPct = d.waterLevelPct.clamp(0.0, 100.0);
    final waterStatus = waterPct < 20 ? 'LOW' : waterPct < 60 ? 'MED' : 'FULL';
    final waterColor = waterPct < 20 ? _kRed : waterPct < 60 ? _kAmber : _kBlue;

    final soilTempStatus = d.soilTempC > 30 ? 'HOT' : 'OK';
    final soilTempColor = d.soilTempC > 30 ? _kRed : _kGreenDark;

    return [
      SensorCard(
        label: 'Soil Moisture',
        value: d.soilMoisturePct.toStringAsFixed(1),
        unit: '%',
        icon: Icons.water_drop_outlined,
        iconColor: _kBlue,
        iconBg: const Color(0xFFEFF6FF),
        progressValue: d.soilMoisturePct / 100,
        progressColor: _kBlue,
        statusLabel: soilStatus,
        statusColor: soilColor,
        rangeText: 'Optimal Range: 30% – 60%',
      ),
      SensorCard(
        label: 'Air Temperature',
        value: d.airTempC.toStringAsFixed(1),
        unit: '°C',
        icon: Icons.thermostat_rounded,
        iconColor: const Color(0xFFF97316),
        iconBg: const Color(0xFFFFF7ED),
        progressValue: (d.airTempC / 50).clamp(0.0, 1.0),
        progressColor: const Color(0xFFF97316),
        statusLabel: tempStatus,
        statusColor: tempColor,
        rangeText: 'Optimal Range: 18°C – 32°C',
      ),
      SensorCard(
        label: 'Humidity',
        value: d.humidityPct.toStringAsFixed(1),
        unit: '%',
        icon: Icons.cloud_rounded,
        iconColor: const Color(0xFF14B8A6),
        iconBg: const Color(0xFFF0FDFA),
        progressValue: d.humidityPct / 100,
        progressColor: const Color(0xFF14B8A6),
        statusLabel: humStatus,
        statusColor: humColor,
        rangeText: 'Optimal Range: 40% – 70%',
      ),
      SensorCard(
        label: 'Light Intensity',
        value: d.lightLux >= 1000
            ? (d.lightLux / 1000).toStringAsFixed(1)
            : d.lightLux.toStringAsFixed(0),
        unit: d.lightLux >= 1000 ? 'k lux' : 'lux',
        icon: Icons.wb_sunny_rounded,
        iconColor: const Color(0xFFEAB308),
        iconBg: const Color(0xFFFEFCE8),
        progressValue: (d.lightLux / 2000).clamp(0.0, 1.0),
        progressColor: const Color(0xFFEAB308),
        statusLabel: lightStatus,
        statusColor: lightColor,
        rangeText: 'Indoor bright: >250 lux',
      ),
      SensorCard(
        label: 'Water Level',
        value: waterPct.toStringAsFixed(0),
        unit: '%',
        icon: Icons.waves_rounded,
        iconColor: _kCyan,
        iconBg: const Color(0xFFECFEFF),
        progressValue: waterPct / 100,
        progressColor: _kCyan,
        statusLabel: waterStatus,
        statusColor: waterColor,
        rangeText: waterPct >= 100 ? 'Tank is full' : 'Tank at ${waterPct.toStringAsFixed(0)}%',
      ),
      SensorCard(
        label: 'Soil Temperature',
        value: d.soilTempC.toStringAsFixed(1),
        unit: '°C',
        icon: Icons.device_thermostat_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFEF2F2),
        progressValue: (d.soilTempC / 40).clamp(0.0, 1.0),
        progressColor: const Color(0xFFEF4444),
        statusLabel: soilTempStatus,
        statusColor: soilTempColor,
        rangeText: 'Optimal Range: 20°C – 30°C',
      ),
    ];
  }
}

// ── App logo chip ──────────────────────────────────────────────────────────────
class _AppLogoChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withOpacity(0.3)),
      ),
      child: const Icon(Icons.eco_rounded, color: _kGreen, size: 20),
    );
  }
}

// ── "All good" badge ───────────────────────────────────────────────────────────
class _AllGoodBadge extends StatelessWidget {
  final SensorData data;
  const _AllGoodBadge({required this.data});

  bool get _allGood =>
      data.soilMoisturePct >= 30 && data.soilMoisturePct <= 60 &&
      data.airTempC <= 35 &&
      data.humidityPct >= 40 && data.humidityPct <= 70;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _allGood ? 'All systems normal' : 'Check alerts',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _allGood ? _kGreenDark : _kRed,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: (_allGood ? _kGreen : _kRed).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _allGood ? Icons.check_rounded : Icons.warning_amber_rounded,
            size: 12,
            color: _allGood ? _kGreenDark : _kRed,
          ),
        ),
      ],
    );
  }
}

// ── Pump control card ──────────────────────────────────────────────────────────
class _PumpCard extends StatelessWidget {
  final SensorData data;
  final AppProvider provider;

  const _PumpCard({required this.data, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isOn = data.pumpRunning;
    final cmd  = provider.pumpCommand;
    final ledOn = isOn || cmd == 'on';

    final statusText = cmd == 'auto'
        ? (isOn ? 'Auto — Running' : 'Idle')
        : cmd == 'on' ? 'Running' : 'Stopped';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kHeroCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kHeroBorder),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: ledOn
                      ? _kGreen.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: ledOn ? _kGreen.withOpacity(0.3) : Colors.white12,
                  ),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: ledOn ? _kGreen : Colors.white38,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water Pump',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      )),
                    Row(
                      children: [
                        Text('Status: ',
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 12,
                          )),
                        Text(statusText,
                          style: GoogleFonts.poppins(
                            color: ledOn ? _kGreen : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                      ],
                    ),
                  ],
                ),
              ),
              // Connected badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kGreen.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(active: true),
                    const SizedBox(width: 5),
                    Text('Connected',
                      style: GoogleFonts.poppins(
                        color: _kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pump buttons
          Row(
            children: [
              _PumpButton(
                label: 'Manual ON',
                sublabel: 'Relay CLOSED',
                icon: Icons.play_arrow_rounded,
                iconColor: _kGreen,
                selected: cmd == 'on',
                selectedColor: _kGreen,
                onTap: () => provider.setPump('on'),
              ),
              const SizedBox(width: 8),
              _PumpButton(
                label: 'Manual OFF',
                sublabel: 'Relay OPEN',
                icon: Icons.stop_rounded,
                iconColor: _kRed,
                selected: cmd == 'off',
                selectedColor: _kRed,
                onTap: () => provider.setPump('off'),
              ),
              const SizedBox(width: 8),
              _PumpButton(
                label: 'Auto Mode',
                sublabel: 'Smart Schedule',
                icon: Icons.auto_mode_rounded,
                iconColor: Colors.white,
                selected: cmd == 'auto',
                selectedColor: _kGreenDark,
                onTap: () => provider.setPump('auto'),
                isAuto: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PumpButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  final bool isAuto;

  const _PumpButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    this.isAuto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? (isAuto ? selectedColor : selectedColor.withOpacity(0.12))
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? (isAuto ? selectedColor : selectedColor.withOpacity(0.4))
                  : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? (isAuto ? Colors.white : selectedColor)
                    : Colors.white38,
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: selected
                      ? (isAuto ? Colors.white : selectedColor)
                      : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sublabel,
                style: GoogleFonts.poppins(
                  color: selected
                      ? (isAuto ? Colors.white70 : selectedColor.withOpacity(0.7))
                      : Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final bool active;
  const _PulsingDot({required this.active});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(width: 6, height: 6,
        decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle));
    }
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 6, height: 6,
        decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
      ),
    );
  }
}

// ── System health card ─────────────────────────────────────────────────────────
class _SystemHealthCard extends StatelessWidget {
  final SensorData data;
  const _SystemHealthCard({required this.data});

  int get _score {
    int score = 100;
    if (data.soilMoisturePct < 30 || data.soilMoisturePct > 60) score -= 20;
    if (data.airTempC > 35) score -= 20;
    if (data.humidityPct < 40 || data.humidityPct > 70) score -= 15;
    if (data.waterLevelPct < 20) score -= 30;
    return score.clamp(0, 100);
  }

  String get _label {
    final s = _score;
    if (s >= 90) return 'Excellent';
    if (s >= 70) return 'Good';
    if (s >= 50) return 'Fair';
    return 'Needs attention';
  }

  Color get _color {
    final s = _score;
    if (s >= 90) return _kGreenDark;
    if (s >= 70) return _kAmber;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.shield_rounded, color: _color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Health',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF111827),
                  )),
                Text(
                  _score >= 90
                      ? 'Everything is running smoothly'
                      : 'Some sensors need attention',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$_score%',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _color,
                )),
              Text(_label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _color,
                )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Loading / no-data ──────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 300,
          color: _kHeroBg,
          child: const Center(
            child: CircularProgressIndicator(color: _kGreen),
          ),
        ),
      ],
    );
  }
}

class _NoDataView extends StatelessWidget {
  const _NoDataView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 300, color: _kHeroBg),
        const SizedBox(height: 80),
        Icon(Icons.sensors_off_rounded, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('No sensor data yet',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          )),
        const SizedBox(height: 6),
        Text('Waiting for ESP32 to connect…',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF9CA3AF),
          )),
      ],
    );
  }
}
