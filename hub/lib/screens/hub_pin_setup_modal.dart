import 'package:flutter/material.dart';
import '../services/launcher_service.dart';
import '../widgets/glass_container.dart';

class HubPinSetupModal extends StatefulWidget {
  final LauncherService launcherService;
  final String? currentPin;
  final bool forceSet;

  const HubPinSetupModal({
    super.key,
    required this.launcherService,
    this.currentPin,
    this.forceSet = false,
  });

  @override
  State<HubPinSetupModal> createState() => _HubPinSetupModalState();
}

class _HubPinSetupModalState extends State<HubPinSetupModal> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (pin.length < 4) {
      setState(() => _error = 'PIN минимум 4 цифры');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PIN не совпадают');
      return;
    }

    setState(() => _busy = true);
    await widget.launcherService.setPin(pin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                    widget.forceSet ? 'Установи PIN' : 'Изменить PIN',
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
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 6),
                decoration: InputDecoration(
                  labelText: 'Новый PIN',
                  hintText: '••••',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                maxLength: 8,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 6),
                decoration: InputDecoration(
                  labelText: 'Повтор',
                  hintText: '••••',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                maxLength: 8,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}