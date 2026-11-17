import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/station.dart';
import '../services/settings.dart';
import '../services/station_repository.dart';
import 'settings_page.dart';
import 'widgets/country_list.dart';
import 'widgets/player_panel.dart';
import 'widgets/station_grid.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _country;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (settings.lastCountry.isNotEmpty) _country = settings.lastCountry;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _select(String code) {
    setState(() {
      _country = code;
      _query = '';
      _searchCtrl.clear();
    });
    settings.saveLastCountry(code);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _update() async {
    final ok = await repo.update();
    _snack(ok
        ? tr('updateDone')
        : '${tr('updateFailed')}: ${repo.lastError ?? ''}');
  }

  void _dedupe() {
    final n = repo.removeDuplicates(
        countryCode: _country == kFavCode ? null : _country);
    _snack(tr('dedupeDone', {'n': n}));
  }

  /// Dialog asking for the scope (this country / everything).
  Future<String?> _askScope(String title, String text) {
    final String c = _country ?? '';
    final hasCountry = c.isNotEmpty && c != kFavCode;
    String scope = hasCountry ? c : '*';
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              const SizedBox(height: 12),
              if (hasCountry)
                _ScopeTile(
                  selected: scope == c,
                  title: tr('scopeCountry', {'c': countryLabelForCode(c)}),
                  onTap: () => setLocal(() => scope = c),
                ),
              _ScopeTile(
                selected: scope == '*',
                title: tr('scopeAll', {'n': repo.visibleCount}),
                onTap: () => setLocal(() => scope = '*'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(context, scope),
                child: Text(tr('start'))),
          ],
        ),
      ),
    );
  }

  Future<void> _showReport(CleanupReport r) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(r.cancelled ? tr('cancelled') : tr('cleanTitle')),
        content: Text(tr('report', {
          'checked': r.checked,
          'ok': r.working,
          'vpn': r.vpn,
          'dead': r.dead,
          'dup': r.duplicates,
        })),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('close'))),
        ],
      ),
    );
  }

  Future<void> _clean() async {
    final scope = await _askScope(tr('cleanTitle'), tr('cleanText'));
    if (scope == null) return;
    final r = await repo.autoClean(countryCode: scope == '*' ? null : scope);
    await _showReport(r);
  }

  Future<void> _check() async {
    final scope = await _askScope(tr('check'), tr('cleanText'));
    if (scope == null) return;
    final r = await repo.checkStreams(
        countryCode: scope == '*' ? null : scope, removeDead: true);
    await _showReport(r);
  }

  void _openSettings() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsPage()));

  void _openPlayerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .92,
        child: const PlayerPanel(),
      ),
    );
  }

  List<Widget> _actions(bool busy) {
    final brightness = Theme.of(context).brightness;
    return [
      IconButton(
        tooltip: tr('update'),
        onPressed: busy ? null : _update,
        icon: const Icon(Icons.refresh_rounded),
      ),
      IconButton(
        tooltip: tr('clean'),
        onPressed: busy ? null : _clean,
        icon: const Icon(Icons.cleaning_services_rounded),
      ),
      IconButton(
        tooltip: brightness == Brightness.dark
            ? tr('themeLight')
            : tr('themeDark'),
        onPressed: () => settings.toggleDark(brightness),
        icon: Icon(brightness == Brightness.dark
            ? Icons.light_mode_rounded
            : Icons.dark_mode_rounded),
      ),
      PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'update':
              _update();
            case 'dedupe':
              _dedupe();
            case 'check':
              _check();
            case 'clean':
              _clean();
            case 'settings':
              _openSettings();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'update',
              enabled: !busy,
              child: ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(tr('update')))),
          PopupMenuItem(
              value: 'dedupe',
              enabled: !busy,
              child: ListTile(
                  leading: const Icon(Icons.filter_alt_rounded),
                  title: Text(tr('dedupe')))),
          PopupMenuItem(
              value: 'check',
              enabled: !busy,
              child: ListTile(
                  leading: const Icon(Icons.network_check_rounded),
                  title: Text(tr('check')))),
          PopupMenuItem(
              value: 'clean',
              enabled: !busy,
              child: ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded),
                  title: Text(tr('clean')))),
          const PopupMenuDivider(),
          PopupMenuItem(
              value: 'settings',
              child: ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: Text(tr('settings')))),
        ],
      ),
    ];
  }

  Widget _busyBar() {
    final b = repo.busy;
    if (b == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = switch (b.label) {
      'update' => '${tr('updating')} ${b.done > 0 ? b.done : ''}',
      'check' => '${tr('checking')} ${b.done} / ${b.total}',
      _ => '${tr('cleaning')} ${b.done} / ${b.total}',
    };
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: b.fraction, minHeight: 3),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer))),
            if (b.cancellable)
              TextButton(
                  onPressed: b.cancelled ? null : repo.cancelBusy,
                  child: Text(tr('cancel'))),
          ]),
        ),
      ]),
    );
  }

  Widget _searchField() => TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: tr('search'),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _query = '';
                    _searchCtrl.clear();
                  }),
                ),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _query = v),
      );

  /// Station area: header (country + search) and the grid.
  Widget _stationArea({required bool showSearch}) {
    final theme = Theme.of(context);
    final searching = _query.trim().isNotEmpty;
    final List<Station> list;
    if (searching) {
      list = repo.search(_query);
    } else if (_country != null) {
      list = repo.stationsOf(_country!);
    } else {
      list = const [];
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          if (!searching && _country != null) ...[
            CountryFlag(code: _country!, width: 32),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              searching
                  ? tr('results', {'n': list.length})
                  : _country == null
                      ? tr('chooseCountry')
                      : '${countryLabelForCode(_country!)} · ${list.length} ${tr('stations')}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showSearch) SizedBox(width: 260, child: _searchField()),
        ]),
      ),
      if (!showSearch)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: _searchField(),
        ),
      Expanded(
        child: (_country == null && !searching)
            ? Center(child: Text(tr('chooseCountry')))
            : StationGrid(stations: list),
      ),
    ]);
  }

  Widget _title() => Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/icon/icon.png', width: 30, height: 30),
        ),
        const SizedBox(width: 10),
        const Text('SlaxxFM',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([repo, settings]),
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final busy = repo.busy != null;
        final scheme = Theme.of(context).colorScheme;

        // ---------------- wide: countries | stations | player
        if (width >= 1100) {
          return Scaffold(
            appBar: AppBar(title: _title(), actions: _actions(busy)),
            body: Column(children: [
              _busyBar(),
              Expanded(
                child: Row(children: [
                  SizedBox(
                    width: 270,
                    child: CountryList(selected: _country, onSelect: _select),
                  ),
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  Expanded(child: _stationArea(showSearch: true)),
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  const SizedBox(width: 360, child: PlayerPanel()),
                ]),
              ),
            ]),
          );
        }

        // ---------------- medium: countries | stations, player bar
        if (width >= 700) {
          return Scaffold(
            appBar: AppBar(title: _title(), actions: _actions(busy)),
            body: Column(children: [
              _busyBar(),
              Expanded(
                child: Row(children: [
                  SizedBox(
                    width: 240,
                    child: CountryList(selected: _country, onSelect: _select),
                  ),
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  Expanded(child: _stationArea(showSearch: width >= 900)),
                ]),
              ),
            ]),
            bottomNavigationBar: MiniPlayerBar(onOpen: _openPlayerSheet),
          );
        }

        // ---------------- phone: countries -> stations
        final inCountry = _country != null || _query.isNotEmpty;
        return PopScope(
          canPop: !inCountry,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              setState(() {
                _country = null;
                _query = '';
                _searchCtrl.clear();
              });
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: inCountry
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setState(() {
                        _country = null;
                        _query = '';
                        _searchCtrl.clear();
                      }),
                    )
                  : null,
              title: _title(),
              actions: _actions(busy),
            ),
            body: Column(children: [
              _busyBar(),
              Expanded(
                child: inCountry
                    ? _stationArea(showSearch: false)
                    : CountryList(selected: _country, onSelect: _select),
              ),
            ]),
            bottomNavigationBar: MiniPlayerBar(onOpen: _openPlayerSheet),
          ),
        );
      },
    );
  }
}

class _ScopeTile extends StatelessWidget {
  final bool selected;
  final String title;
  final VoidCallback onTap;
  const _ScopeTile(
      {required this.selected, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(title),
        onTap: onTap,
      );
}
