// tv/lib/main.dart
//
// Вместе ТВ — лаунчер для телевизора на Windows.
// Киоск-fullscreen, синк только чтение из main, геймпад, экранная клава.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/tv_home_screen.dart';
import 'screens/tv_setup_screen.dart';
import 'services/gamepad_service.dart';
import 'services/osk_service.dart';
import 'services/tiles_service.dart';
import 'services/tv_sync_service.dart';
import 'supabase_config.dart';
import 'theme/tv_theme.dart';
import 'widgets/osk_panel.dart';
import 'widgets/tv_focusable.dart';
import 'widgets/tv_gamepad_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final TvSyncService sync = TvSyncService();
final TilesService tiles = TilesService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await tiles.init();
  GamepadService.instance.init();

  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Color(0xFF0F0F0F),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Вместе ТВ',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setFullScreen(true);
  });
  windowManager.addListener(_AppWindowListener());

  runApp(const VmesteTvApp());
  unawaited(sync.init());
}

class _AppWindowListener with WindowListener {
  @override
  void onWindowClose() {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) showExitDialog(ctx);
  }

  @override
  void onWindowRestore() {
    windowManager.setFullScreen(true);
  }
}

Future<void> showExitDialog(BuildContext context) async {
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: TvColors.cardHi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Выйти в Windows?', style: TvText.cardTitle),
      content: Text(
        'Лаунчер закроется, и ты увидишь обычный рабочий стол.',
        style: TvText.bodyDim,
      ),
      actions: [
        TvDialogButton(label: 'Отмена', onTap: () => Navigator.pop(ctx, 'cancel')),
        TvDialogButton(label: 'Свернуть', onTap: () => Navigator.pop(ctx, 'min')),
        TvDialogButton(label: 'Выйти', danger: true, onTap: () => Navigator.pop(ctx, 'exit')),
      ],
    ),
  );
  if (action == 'min') {
    await windowManager.setFullScreen(false);
    await windowManager.minimize();
  }
  if (action == 'exit') {
    await windowManager.destroy();
    exit(0);
  }
}

class VmesteTvApp extends StatelessWidget {
  const VmesteTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Вместе ТВ',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: TvTheme.dark.copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thickness: MaterialStateProperty.all(8),
          radius: const Radius.circular(8),
          thumbColor: MaterialStateProperty.all(TvColors.accentDeep),
          trackColor: MaterialStateProperty.all(TvColors.card),
        ),
      ),
      home: AnimatedBuilder(
        animation: sync,
        builder: (_, __) =>
            sync.hasGroup ? const TvHomeScreen() : const TvSetupScreen(),
      ),
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: TvGamepadGate(
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const OskOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}
