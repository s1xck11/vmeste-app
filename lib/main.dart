// В _MainScreenState.initState:

_screens = [
  PurchasesScreen(
    storage: widget.storage,
    sync: widget.sync,
    themeService: widget.themeService,
    onAvatarTap: _openSettings,
  ),
  TasksScreen(
    storage: widget.storage,
    sync: widget.sync,
    themeService: widget.themeService,
    onAvatarTap: _openSettings,
  ),
  ShiftsScreen(
    storage: widget.storage,
    sync: widget.sync,
    themeService: widget.themeService,
    onAvatarTap: _openSettings,
  ),
  BudgetScreen(
    storage: widget.storage,
    sync: widget.sync,
    themeService: widget.themeService,
    onAvatarTap: _openSettings,
  ),
];