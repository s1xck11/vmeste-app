import 'package:flutter/material.dart';
import '../services/tuya_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/pressable.dart';

class HubLightsScreen extends StatefulWidget {
  final TuyaService tuyaService;
  final VoidCallback onOpenTuyaSetup;

  const HubLightsScreen({
    super.key,
    required this.tuyaService,
    required this.onOpenTuyaSetup,
  });

  @override
  State<HubLightsScreen> createState() => _HubLightsScreenState();
}

class _HubLightsScreenState extends State<HubLightsScreen> {
  List<TuyaDevice> _devices = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.tuyaService.isConfigured) return;
    setState(() => _loading = true);
    final devices = await widget.tuyaService.getDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _toggle(TuyaDevice device) async {
    final newState = !device.isOn;
    setState(() {
      final i = _devices.indexWhere((d) => d.id == device.id);
      if (i >= 0) _devices[i] = device.copyWith(isOn: newState);
    });
    await widget.tuyaService.sendCommand(device.id, [
      {'code': 'switch_led', 'value': newState}
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: cs.secondary, size: 32),
              const SizedBox(width: 14),
              Text(
                'Свет',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh, color: cs.primary, size: 28),
                onPressed: _loading ? null : _load,
              ),
              IconButton(
                icon: Icon(Icons.settings, color: cs.primary, size: 28),
                onPressed: widget.onOpenTuyaSetup,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: !widget.tuyaService.isConfigured
                ? _buildSetupHint(cs)
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _devices.isEmpty
                        ? _buildEmpty(cs)
                        : _buildDevicesGrid(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupHint(ColorScheme cs) {
    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 80, color: cs.onSurfaceVariant),
            const SizedBox(height: 24),
            Text(
              'Tuya не настроен',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Введи Access ID и Secret от developer.tuya.com',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onOpenTuyaSetup,
              icon: const Icon(Icons.settings),
              label: const Text('Настроить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 80, color: cs.onSurfaceVariant),
            const SizedBox(height: 24),
            Text(
              'Устройства не найдены',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Убедись, что лампы привязаны в приложении Camelion',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesGrid(ColorScheme cs) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 1.0,
      ),
      itemCount: _devices.length,
      itemBuilder: (ctx, i) {
        final d = _devices[i];
        return Pressable(
          onTap: () => _toggle(d),
          child: GlassContainer(
            radius: 32,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  d.isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                  size: 64,
                  color: d.isOn ? cs.secondary : cs.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  d.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: d.isOn ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  d.online ? (d.isOn ? 'Вкл' : 'Выкл') : 'Офлайн',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: d.online
                        ? (d.isOn ? cs.secondary : cs.onSurfaceVariant)
                        : cs.error,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}