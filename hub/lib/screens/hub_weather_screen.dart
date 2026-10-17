import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Погода',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              if (widget.weatherService.cityName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.weatherService.cityName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.location_city, color: cs.primary),
                tooltip: 'Сменить город',
                onPressed: _pickCity,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: cs.primary),
                onPressed: _loading ? null : _refresh,
              ),
            ],
          ),
          const SizedBox(height: 16),
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
      radius: 28,
      showAllBorder: true,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Город не выбран',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Выбери город, чтобы видеть погоду',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickCity,
              icon: const Icon(Icons.search),
              label: const Text('Выбрать город'),
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
          radius: 28,
          showAllBorder: true,
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Text(
                now?.emoji ?? '🌡',
                style: const TextStyle(fontSize: 80),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${now?.temperature.round() ?? '—'}°',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      now?.description ?? '—',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 10),
                  _stat(Icons.water_drop_outlined, '${now?.humidity ?? '—'}%', 'Влажность', cs),
                  const SizedBox(height: 10),
                  _stat(Icons.air, '${now?.windSpeed.round() ?? '—'} м/с', 'Ветер', cs),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GlassContainer(
            radius: 28,
            showAllBorder: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогноз на 7 дней',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: c.days.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outline.withOpacity(0.5),
                    ),
                    itemBuilder: (ctx, i) {
                      final d = c.days[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                d.dayLabel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Text(d.emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                // БЫЛО: WeatherNow._describeWmo(d.weatherCode)
                                WeatherNow.describeWmo(d.weatherCode),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '${d.tempMin.round()}°',
                              style: TextStyle(
                                fontSize: 15,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${d.tempMax.round()}°',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
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
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}