import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sensor_data.dart';
import '../../providers/app_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selected = 0;

  static const _fields = [
    _ChartField('Soil Moisture', 'soilMoisture', '%',   Color(0xFF1E88E5)),
    _ChartField('Air Temp',      'airTemp',      '°C',  Color(0xFFFF7043)),
    _ChartField('Humidity',      'humidity',     '%',   Color(0xFF26A69A)),
    _ChartField('Light',         'lightLux',     'lux', Color(0xFFFFB300)),
    _ChartField('Water Level',   'waterLevelPct', '%',  Color(0xFF1565C0)),
    _ChartField('Soil Temp',     'soilTemp',     '°C',  Color(0xFF6D4C41)),
  ];

  final Map<String, List<SensorHistory>> _cache = {};
  bool _loading = false;
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _loadSelected();
  }

  String get _currentField => _fields[_selected].field;

  Future<void> _loadSelected({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(_currentField)) return;
    if (mounted) setState(() => _loading = true);
    final data = await context.read<AppProvider>().fetchHistory(_currentField);
    if (mounted) {
      setState(() {
        _cache[_currentField] = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final field   = _fields[_selected];
    final history = _cache[_currentField] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor History'),
        actions: [
          IconButton(
            icon: Icon(_showList ? Icons.show_chart_rounded : Icons.list_rounded),
            tooltip: _showList ? 'Show chart' : 'Show list',
            onPressed: () => setState(() => _showList = !_showList),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _loadSelected(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sensor chips ─────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _fields.length,
              itemBuilder: (_, i) {
                final f = _fields[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: FilterChip(
                    label: Text(f.label, style: const TextStyle(fontSize: 12)),
                    selected: _selected == i,
                    selectedColor: f.color.withOpacity(0.15),
                    checkmarkColor: f.color,
                    onSelected: (_) {
                      setState(() {
                        _selected = i;
                        _showList = false;
                      });
                      _loadSelected();
                    },
                  ),
                );
              },
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : history.isEmpty
                    ? _EmptyState(field: field)
                    : _showList
                        ? _DataList(data: history, field: field)
                        : _ChartWithStats(data: history, field: field),
          ),
        ],
      ),
    );
  }
}

// ── Line chart + stats summary ────────────────────────────────────────────────
class _ChartWithStats extends StatelessWidget {
  final List<SensorHistory> data;
  final _ChartField field;
  const _ChartWithStats({required this.data, required this.field});

  @override
  Widget build(BuildContext context) {
    final values = data.map((d) => d.value).toList();
    final minV   = values.reduce((a, b) => a < b ? a : b);
    final maxV   = values.reduce((a, b) => a > b ? a : b);
    final avgV   = values.reduce((a, b) => a + b) / values.length;
    final range  = (maxV - minV).clamp(1.0, double.infinity);

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return Column(
      children: [
        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _StatChip('Min', '${minV.toStringAsFixed(1)}${field.unit}', Colors.blue),
              const SizedBox(width: 8),
              _StatChip('Avg', '${avgV.toStringAsFixed(1)}${field.unit}', field.color),
              const SizedBox(width: 8),
              _StatChip('Max', '${maxV.toStringAsFixed(1)}${field.unit}', Colors.red),
              const Spacer(),
              Text('${data.length} readings',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
            child: LineChart(
              LineChartData(
                minY: (minV - range * 0.15).floorToDouble(),
                maxY: (maxV + range * 0.15).ceilToDouble(),
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (val, _) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${val.toStringAsFixed(0)}${field.unit}',
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (spots.length / 4).ceilToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        return Text(
                          DateFormat('HH:mm').format(data[idx].timestamp),
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt();
                      final time = idx < data.length
                          ? DateFormat('HH:mm').format(data[idx].timestamp)
                          : '';
                      return LineTooltipItem(
                        '$time\n${s.y.toStringAsFixed(1)}${field.unit}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: field.color,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: data.length <= 20,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: field.color,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          field.color.withOpacity(0.25),
                          field.color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Data list view ────────────────────────────────────────────────────────────
class _DataList extends StatelessWidget {
  final List<SensorHistory> data;
  final _ChartField field;
  const _DataList({required this.data, required this.field});

  @override
  Widget build(BuildContext context) {
    final reversed = data.reversed.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reversed.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final entry = reversed[i];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: field.color.withOpacity(0.1),
            child: Icon(Icons.show_chart_rounded, color: field.color, size: 16),
          ),
          title: Text(
            '${entry.value.toStringAsFixed(1)} ${field.unit}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            DateFormat('HH:mm · dd MMM').format(entry.timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _ChartField field;
  const _EmptyState({required this.field});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No ${field.label} history yet',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Data will appear once the ESP32 starts sending',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChartField {
  final String label;
  final String field;
  final String unit;
  final Color color;
  const _ChartField(this.label, this.field, this.unit, this.color);
}
