import 'package:flutter/material.dart';
import '../services/tuya_service.dart';
import '../widgets/glass_container.dart';

class HubTuyaSetupModal extends StatefulWidget {
  final TuyaService tuyaService;

  const HubTuyaSetupModal({
    super.key,
    required this.tuyaService,
  });

  @override
  State<HubTuyaSetupModal> createState() => _HubTuyaSetupModalState();
}

class _HubTuyaSetupModalState extends State<HubTuyaSetupModal> {
  final _idCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  String _region = 'eu';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idCtrl.text = widget.tuyaService.accessId;
    _secretCtrl.text = widget.tuyaService.accessSecret;
    _region = widget.tuyaService.region;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _idCtrl.text.trim();
    final secret = _secretCtrl.text.trim();
    if (id.isEmpty || secret.isEmpty) {
      setState(() => _error = 'Заполни оба поля');
      return;
    }
    setState(() => _busy = true);
    await widget.tuyaService.setCredentials(
      accessId: id,
      accessSecret: secret,
      region: _region,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: GlassContainer(
          radius: 28,
          showAllBorder: true,
          shadow: true,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Настройка Tuya',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _idCtrl,
                decoration: InputDecoration(
                  labelText: 'Access ID (Client ID)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secretCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Access Secret',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _region,
                decoration: InputDecoration(
                  labelText: 'Регион',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: const [
                  DropdownMenuItem(value: 'eu', child: Text('Europe (Central)')),
                  DropdownMenuItem(value: 'us', child: Text('America')),
                  DropdownMenuItem(value: 'cn', child: Text('China')),
                  DropdownMenuItem(value: 'in', child: Text('India')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _region = v);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Ключи можно получить на developer.tuya.com —\nсоздай Cloud Project и привяжи аккаунт Camelion.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}