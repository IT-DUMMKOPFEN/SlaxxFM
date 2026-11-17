import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';

import '../l10n.dart';
import '../models/station.dart';
import '../ui/widgets/country_list.dart' show countryLabelForCode;
import 'player_service.dart';
import 'settings.dart';
import 'station_repository.dart';

/// Connects the player to Android's media system:
///  * foreground service + media notification (playback keeps running
///    with the screen off / app in background),
///  * lock screen, headset and Bluetooth controls,
///  * Android Auto: browsing (Favorites / Recent / Countries), voice
///    search ("play … on SlaxxFM"), next / previous station.
class RadioAudioHandler extends BaseAudioHandler {
  static const _root = AudioService.browsableRootId; // 'root'
  static const _recent = AudioService.recentRootId; // 'recent'
  static const _fav = 'fav';
  static const _countries = 'countries';
  static const _countryPrefix = 'c:';
  static const _maxItems = 300;

  String _lastItemKey = '';
  String _lastStateKey = '';

  RadioAudioHandler() {
    player.addListener(_sync);
    _sync();
  }

  // ----------------------------------------------------------- state sync

  MediaItem _stationItem(Station s, {String nowPlaying = ''}) {
    final country = countryLabelForCode(s.countryCode);
    final hasTitle = nowPlaying.isNotEmpty;
    final art = s.logo.startsWith('http') ? Uri.tryParse(s.logo) : null;
    return MediaItem(
      id: s.id,
      title: hasTitle ? nowPlaying : s.name,
      artist: hasTitle ? s.name : country,
      album: 'SlaxxFM · $country',
      genre: s.tagList.isEmpty ? null : s.tagList.first,
      artUri: art,
      playable: true,
      displayTitle: hasTitle ? nowPlaying : s.name,
      displaySubtitle: hasTitle ? s.name : country,
    );
  }

  void _sync() {
    final s = player.current;
    if (s != null) {
      final key = '${s.id}|${player.nowPlaying}';
      if (key != _lastItemKey) {
        _lastItemKey = key;
        mediaItem.add(_stationItem(s, nowPlaying: player.nowPlaying));
      }
    }
    final active = player.active;
    final loading = active && (player.buffering || !player.playing);
    final processing = s == null
        ? AudioProcessingState.idle
        : loading
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready;
    final stateKey = '$active|$processing|${s?.id}';
    if (stateKey == _lastStateKey) return;
    _lastStateKey = stateKey;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        active ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.playFromMediaId,
        MediaAction.playFromSearch,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processing,
      playing: active,
    ));
  }

  // ----------------------------------------------------------- controls

  @override
  Future<void> play() => player.resume();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    _lastStateKey = '';
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> skipToNext() => player.next();

  @override
  Future<void> skipToPrevious() => player.previous();

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    await repo.ready;
    final s = repo.byId(mediaId);
    if (s == null) return;
    await player.play(s, queue: _queueFor(s));
  }

  @override
  Future<void> playFromSearch(String query,
      [Map<String, dynamic>? extras]) async {
    await repo.ready;
    var results = query.trim().isEmpty ? _recentStations() : repo.search(query);
    if (results.isEmpty) results = _favoriteStations();
    if (results.isEmpty) return;
    await player.play(results.first, queue: results.take(_maxItems).toList());
  }

  // ----------------------------------------------------------- browsing

  List<Station> _favoriteStations() => repo.stationsOf(kFavCode);

  List<Station> _recentStations() => settings.recent
      .map(repo.byId)
      .whereType<Station>()
      .toList();

  /// Queue for next/previous: the list the station appears in.
  List<Station> _queueFor(Station s) {
    if (repo.isFavorite(s)) return _favoriteStations();
    return repo.stationsOf(s.countryCode).take(_maxItems).toList();
  }

  MediaItem _folder(String id, String title, {String? subtitle, Uri? art}) =>
      MediaItem(
        id: id,
        title: title,
        displaySubtitle: subtitle,
        playable: false,
        artUri: art,
      );

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    await repo.ready;
    switch (parentMediaId) {
      case _root:
        return [
          _folder(_fav, tr('favorites')),
          _folder(_recent, tr('recent')),
          _folder(_countries, tr('countries')),
        ];
      case _fav:
        return _favoriteStations().take(_maxItems).map(_stationItem).toList();
      case _recent:
        return _recentStations().map(_stationItem).toList();
      case _countries:
        return repo.countries
            .where((c) => c.code != kFavCode && c.count > 0)
            .map((c) => _folder(
                  '$_countryPrefix${c.code}',
                  countryLabelForCode(c.code),
                  subtitle: '${c.count} ${tr('stations')}',
                  art: c.code == kIntlCode
                      ? null
                      : Uri.parse(
                          'https://flagcdn.com/w160/${c.code.toLowerCase()}.png'),
                ))
            .toList();
    }
    if (parentMediaId.startsWith(_countryPrefix)) {
      final code = parentMediaId.substring(_countryPrefix.length);
      return repo.stationsOf(code).take(_maxItems).map(_stationItem).toList();
    }
    return const [];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    await repo.ready;
    final s = repo.byId(mediaId);
    return s == null ? null : _stationItem(s);
  }

  @override
  Future<List<MediaItem>> search(String query,
      [Map<String, dynamic>? extras]) async {
    await repo.ready;
    return repo.search(query).take(_maxItems).map(_stationItem).toList();
  }
}

/// Starts the Android media service (no-op on desktop).
Future<void> initAudioService() async {
  if (!Platform.isAndroid) return;
  try {
    await AudioService.init(
      builder: () => RadioAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'de.itdummkopfen.slaxxfm.playback',
        androidNotificationChannelName: 'SlaxxFM',
        androidNotificationIcon: 'drawable/ic_stat_radio',
        androidStopForegroundOnPause: true,
        androidNotificationOngoing: false,
      ),
    );
  } catch (_) {
    // the app still works in the foreground without the service
  }
}
