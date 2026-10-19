import 'package:flutter/material.dart';
import 'package:dpad/dpad.dart';
import '../services/storage_service.dart';
import '../services/weather_service.dart';
import '../widgets/glass_container.dart';
import 'hub_city_picker.dart';

class HubWeatherScreen extends StatefulWidget {
  final StorageService storage;
  final WeatherService weatherService;

  const HubWeatherScreen({
    super.key,
    required this.storage,
    required this.weatherService,
  });

  @override
  State<HubWeatherScreen> createState() => _HubWeatherScreenState();
}

class _HubWeatherScreenState extends State<HubWeatherScreen> {
  WeatherCache? _cache;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cache = widget.weatherService.lastKnown;
    _refresh();
  }

  Future<void> _refresh() async {
    if (!widget.weatherService.hasCity) return;
    setState(() => _loading = true);
    final c = await widget.weatherService.fetch(force: true);
    if (!mounted) return;
    setState(() {
      _cache = c;
      _loading = false;
    });
  }

  Future<void> _pickCity() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => HubCityPicker(weatherService: widget.weatherService),
    );
    if (ok == true) {
      _refresh();
    }
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
              Text(
                'Погода',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 16),
              if (widget.weatherService.cityName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.weatherService.cityName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              const Spacer(),
              DpadFocusable(
                onSelect: _pickCity,
                effects: [DpadBorderEffect(color: cs.primary, width: 2)],
                child: IconButton(
                  icon: Icon(Icons.location_city, color: cs.primary, size: 28),
                  tooltip: 'Сменить город',
                  onPressed: _pickCity,
                ),
              ),
              DpadFocusable(
                onSelect: _refresh,
                effects: [DpadBorderEffect(color: cs.primary, width: 2)],
                child: IconButton(
                  icon: Icon(Icons.refresh, color: cs.primary, size: 28),
                  onPressed: _loading ? null : _refresh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: !widget.weatherService.hasCity
                ? _buildNoCity(cs)
                : _loading && _cache == null
                    ? const Center(child: CircularProgressIndicator())
                    : _cache == null
                        ? const Center(child: Text('Нет данных'))
                        : _buildContent(cs, _cache!),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCity(ColorScheme cs) {
    return GlassContainer(
      radius: 32,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 80, color: cs.onSurfaceVariant),
            const SizedBox(height: 24),
            Text(
              'Город не выбран',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Выбери город, чтобы видеть погоду',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            DpadFocusable(
              autofocus: true,
              onSelect: _pickCity,
              effects: [DpadBorderEffect(color: cs.primary, width: 3)],
              child: ElevatedButton.icon(
                onPressed: _pickCity,
                icon: const Icon(Icons.search),
                label: const Text('Выбрать город'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, WeatherCache c) {
    final now = c.now;

    return Column(
      children: [
        GlassContainer(
          radius: 32,
          padding: const EdgeInsets.all(32),
          child: Row(
            children: [
              Text(
                now?.emoji ?? '🌡',
                style: const TextStyle(fontSize: 96),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${now?.temperature.round() ?? '—'}°',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -3,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      now?.description ?? '—',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _stat(Icons.thermostat, '${now?.feelsLike.round() ?? '—'}°', 'Ощущается', cs),
                  const SizedBox(height: 16),
                  _stat(Icons.water_drop_outlined, '${now?.humidity ?? '—'}%', 'Влажность', cs),
                  const SizedBox(height: 16),
                  _stat(Icons.air, '${now?.windSpeed.round() ?? '—'} м/с', 'Ветер', cs),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GlassContainer(
            radius: 32,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогноз на 7 дней',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: c.days.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outline.withOpacity(0.4),
                    ),
                    itemBuilder: (ctx, i) {
                      final d = c.days[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(
                                d.dayLabel,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Text(d.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                WeatherNow.describeWmo(d.weatherCode),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '${d.tempMin.round()}°',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '${d.tempMax.round()}°',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 22, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}