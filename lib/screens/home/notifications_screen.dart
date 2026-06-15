import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/alert.dart';
import '../../providers/app_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final alerts = provider.alerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (alerts.any((a) => !a.read))
            TextButton(
              onPressed: () => provider.markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: alerts.isEmpty
          ? _EmptyView()
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) => _AlertTile(alert: alerts[i]),
            ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final PlantAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final color = Theme.of(context).colorScheme;

    return Card(
      color: alert.read ? null : color.primaryContainer.withOpacity(0.3),
      child: ListTile(
        leading: Text(alert.icon, style: const TextStyle(fontSize: 26)),
        title: Text(
          alert.message,
          style: TextStyle(
            fontWeight: alert.read ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          DateFormat('dd MMM, HH:mm').format(alert.timestamp),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: !alert.read
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: alert.read ? null : () => provider.markAlertRead(alert.id),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text('No notifications'),
        ],
      ),
    );
  }
}
