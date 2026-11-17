import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../models/station.dart';
import '../../services/station_repository.dart';

String countryLabel(CountryInfo c) {
  if (c.code == kFavCode) return tr('favorites');
  if (c.code == kIntlCode) return tr('international');
  return c.name;
}

String countryLabelForCode(String code) {
  for (final c in repo.countries) {
    if (c.code == code) return countryLabel(c);
  }
  return code;
}

class CountryFlag extends StatelessWidget {
  final String code;
  final double width;
  const CountryFlag({super.key, required this.code, this.width = 28});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (code == kFavCode) {
      return SizedBox(
          width: width,
          child: Icon(Icons.star_rounded, color: Colors.amber, size: width * .8));
    }
    if (code == kIntlCode) {
      return SizedBox(
          width: width,
          child: Icon(Icons.public, color: scheme.primary, size: width * .8));
    }
    final text = Container(
      width: width,
      height: width * .7,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(code,
          style: TextStyle(fontSize: width * .32, fontWeight: FontWeight.bold)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        'https://flagcdn.com/w80/${code.toLowerCase()}.png',
        width: width,
        height: width * .7,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => text,
        frameBuilder: (context, child, frame, sync) =>
            frame == null && !sync ? text : child,
      ),
    );
  }
}

class CountryList extends StatefulWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  const CountryList({super.key, required this.selected, required this.onSelect});

  @override
  State<CountryList> createState() => _CountryListState();
}

class _CountryListState extends State<CountryList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final q = _filter.trim().toLowerCase();
        final items = repo.countries
            .where((c) =>
                q.isEmpty ||
                countryLabel(c).toLowerCase().contains(q) ||
                c.code.toLowerCase() == q)
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                decoration: InputDecoration(
                  hintText: tr('searchCountry'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  final sel = c.code == widget.selected;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    child: ListTile(
                      dense: true,
                      selected: sel,
                      selectedTileColor: scheme.primaryContainer,
                      selectedColor: scheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: CountryFlag(code: c.code),
                      title: Text(countryLabel(c),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('${c.count}',
                          style: Theme.of(context).textTheme.labelSmall),
                      onTap: () => widget.onSelect(c.code),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
