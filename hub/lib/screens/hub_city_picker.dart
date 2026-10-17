import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/glass_container.dart';

/// Модалка для выбора города. Открывается из настроек погоды.
class HubCityPicker extends StatefulWidget {
  final WeatherService weatherService;

  const HubCityPicker({
    super.key,
    required this.weatherService,
  });

  @override
  State<HubCityPicker> createState() => _HubCityPickerState();
}

class _HubCityPickerState extends State<HubCityPicker> {
  final _ctrl = TextEditingController();
  final _geocoding = GeocodingService();

  bool _loading = false;
  List<GeoResult> _results = [];
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    final res = await _geocoding.search(q);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = res;
      if (res.isEmpty) _error = 'Ничего не найдено';
    });
  }

  Future<void> _pick(GeoResult r) async {
    await widget.weatherService.setCity(
      name: r.name,
      lat: r.lat,
      lon: r.lon,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                    'Выбрать город',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Москва, Санкт-Петербург, ...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else if (_results.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) {
                      final r = _results[i];
                      return ListTile(
                        onTap: () => _pick(r),
                        title: Text(
                          r.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          r.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}