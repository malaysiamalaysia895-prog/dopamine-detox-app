import 'dart:async';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';

class StudyFocusScreen extends StatefulWidget {
  const StudyFocusScreen({super.key});

  @override
  State<StudyFocusScreen> createState() => _StudyFocusScreenState();
}

class _StudyFocusScreenState extends State<StudyFocusScreen> {
  List<Application> _installedApps = [];
  final Set<String> _selectedPackages = {};
  Duration _selectedDuration = const Duration(hours: 1);
  bool _loadingApps = true;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadApps();
  }

  Future<void> _checkPermissionsAndLoadApps() async {
    // Check overlay permission
    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) {
      await FlutterOverlayWindow.requestPermission();
    }

    // Check usage stats permission (Android special permission)
    // We guide the user to settings since it can't be requested programmatically
    setState(() => _permissionsGranted = overlayGranted);

    await _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      apps.sort((a, b) =>
          a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
      setState(() {
        _installedApps = apps;
        _loadingApps = false;
      });
    } catch (e) {
      setState(() => _loadingApps = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps: $e')),
        );
      }
    }
  }

  Future<void> _startFocus() async {
    if (_selectedPackages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one app to lock.')),
      );
      return;
    }

    final provider = context.read<AppStateProvider>();
    final billing = context.read<BillingService>();

    // Wire billing callback
    billing.onPurchaseSuccess = () {
      provider.unlockAll();
      if (mounted) {
        Navigator.popUntil(context, (r) => r.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Penalty paid — lock removed.')),
        );
      }
    };

    provider.startStudyFocus(
      packages: _selectedPackages.toList(),
      duration: _selectedDuration,
    );

    // Show overlay window permission dialog if needed
    await _ensureOverlayActive();

    if (mounted) Navigator.pop(context);
  }

  Future<void> _ensureOverlayActive() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    // Show the overlay
    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      overlayTitle: 'Study Focus Active',
      overlayContent: 'Kripya apna challenge complete karein.',
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.center,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: WindowSize.fullCover,
      width: WindowSize.fullCover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppTheme.bg,
            pinned: true,
            expandedHeight: 160,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Study Focus',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 20),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF0D0D1A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                  child: Text('📚', style: TextStyle(fontSize: 60)),
                ),
              ),
            ),
          ),

          // Duration picker
          SliverToBoxAdapter(
            child: _DurationSection(
              selected: _selectedDuration,
              onChanged: (d) => setState(() => _selectedDuration = d),
            ),
          ),

          // App list header
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Select Apps to Lock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedPackages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_selectedPackages.length} selected',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // App list
          _loadingApps
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: AppTheme.primary),
                        const SizedBox(height: 16),
                        const Text('Loading installed apps...',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final app = _installedApps[index];
                        final isSelected =
                            _selectedPackages.contains(app.packageName);
                        return _AppTile(
                          app: app,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPackages.remove(app.packageName);
                              } else {
                                _selectedPackages.add(app.packageName);
                              }
                            });
                          },
                        );
                      },
                      childCount: _installedApps.length,
                    ),
                  ),
                ),
        ],
      ),

      // Start button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: GestureDetector(
            onTap: _startFocus,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF5C6BC0)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '🔒 Start Study Focus',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Duration Section ─────────────────────────────────────────────────────────
class _DurationSection extends StatelessWidget {
  final Duration selected;
  final ValueChanged<Duration> onChanged;

  const _DurationSection({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final durations = [
      const Duration(minutes: 25),
      const Duration(minutes: 45),
      const Duration(hours: 1),
      const Duration(hours: 2),
      const Duration(hours: 3),
      const Duration(hours: 4),
    ];

    String label(Duration d) {
      if (d.inMinutes < 60) return '${d.inMinutes}m';
      return '${d.inHours}h';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lock Duration',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: durations
                .map((d) => GestureDetector(
                      onTap: () => onChanged(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected == d
                              ? AppTheme.primary
                              : AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.4)),
                        ),
                        child: Text(
                          label(d),
                          style: TextStyle(
                            color: selected == d
                                ? Colors.white
                                : AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── App Tile ─────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final Application app;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppTile({
    required this.app,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appWithIcon = app is ApplicationWithIcon
        ? app as ApplicationWithIcon
        : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.15)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            // App icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: appWithIcon != null
                  ? Image.memory(
                      appWithIcon.icon,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      color: AppTheme.surface,
                      child: const Icon(Icons.android,
                          color: Colors.white54, size: 24),
                    ),
            ),
            const SizedBox(width: 14),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    app.packageName,
                    style: const TextStyle(
                      color: Color(0xFF6666AA),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
