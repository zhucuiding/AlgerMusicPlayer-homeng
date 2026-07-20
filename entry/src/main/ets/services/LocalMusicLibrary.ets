import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  LocalSong,
  Song,
  StoredSong,
  StoredPlaylist,
  Playlist,
  PlaylistItem,
  toStoredSong,
  songKey,
  toStoredPlaylist,
  toPlaylist,
  HistoryEntry,
  StoredHistoryEntry,
  toStoredHistory,
  toHistoryEntry,
  AppSettings
} from '../model/MusicModels';

const STORE_NAME = 'local_music_library';
const FAVORITES_KEY = 'favorites';
const COLLECTION_KEY = 'collection';
const PLAYLIST_QUEUE_KEY = 'playlist_queue';
const PLAYER_SETTINGS_KEY = 'player_settings';
const HISTORY_KEY = 'play_history';
const CUSTOM_PLAYLISTS_KEY = 'custom_playlists';
const SEARCH_HISTORY_KEY = 'search_history';

const MAX_HISTORY = 200;

export class LocalMusicLibrary {
  private store?: preferences.Preferences;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.store = await preferences.getPreferences(context, STORE_NAME);
  }

  async loadFavorites(): Promise<Song[]> {
    return this.load(FAVORITES_KEY);
  }

  async loadPlaylist(): Promise<Song[]> {
    return this.load(PLAYLIST_QUEUE_KEY);
  }

  async loadCollection(): Promise<Song[]> {
    return this.load(COLLECTION_KEY);
  }

  async saveFavorites(songs: Song[]): Promise<void> {
    await this.save(FAVORITES_KEY, songs);
  }

  async savePlaylist(songs: Song[]): Promise<void> {
    await this.save(PLAYLIST_QUEUE_KEY, songs);
  }

  async saveCollection(songs: Song[]): Promise<void> {
    await this.save(COLLECTION_KEY, songs);
  }

  async loadSettings(): Promise<AppSettings> {
    const store = this.requireStore();
    const value = await store.get(PLAYER_SETTINGS_KEY, JSON.stringify(this.defaultSettings()));
    try {
      const parsed = JSON.parse(value as string) as AppSettings;
      const merged: AppSettings = this.defaultSettings();
      merged.playMode = parsed.playMode ?? merged.playMode;
      merged.volume = parsed.volume ?? merged.volume;
      merged.theme = parsed.theme ?? merged.theme;
      merged.quality = parsed.quality ?? merged.quality;
      merged.playbackSpeed = parsed.playbackSpeed ?? merged.playbackSpeed;
      merged.equalizerEnabled = parsed.equalizerEnabled ?? merged.equalizerEnabled;
      merged.equalizerPreset = parsed.equalizerPreset ?? merged.equalizerPreset;
      return merged;
    } catch (e) {
      return this.defaultSettings();
    }
  }

  async saveSettings(settings: AppSettings): Promise<void> {
    const store = this.requireStore();
    await store.put(PLAYER_SETTINGS_KEY, JSON.stringify(settings));
    await store.flush();
  }

  async loadHistory(): Promise<HistoryEntry[]> {
    const store = this.requireStore();
    const value = await store.get(HISTORY_KEY, '[]');
    try {
      const data = JSON.parse(value as string) as StoredHistoryEntry[];
      return data.map((item: StoredHistoryEntry) => toHistoryEntry(item));
    } catch (e) {
      return [];
    }
  }

  async addHistory(song: Song): Promise<HistoryEntry[]> {
    const history = await this.loadHistory();
    const filtered = history.filter((e: HistoryEntry) => songKey(e.song) !== songKey(song));
    const newEntry: HistoryEntry = { song, playedAt: Date.now() };
    const updated: HistoryEntry[] = [newEntry].concat(filtered).slice(0, MAX_HISTORY);
    const store = this.requireStore();
    const data = updated.map((e: HistoryEntry) => toStoredHistory(e));
    await store.put(HISTORY_KEY, JSON.stringify(data));
    await store.flush();
    return updated;
  }

  async clearHistory(): Promise<void> {
    const store = this.requireStore();
    await store.put(HISTORY_KEY, '[]');
    await store.flush();
  }

  async loadCustomPlaylists(): Promise<Playlist[]> {
    const store = this.requireStore();
    const value = await store.get(CUSTOM_PLAYLISTS_KEY, '[]');
    try {
      const data = JSON.parse(value as string) as StoredPlaylist[];
      return data.map((s: StoredPlaylist) => toPlaylist(s));
    } catch (e) {
      return [];
    }
  }

  async saveCustomPlaylists(playlists: Playlist[]): Promise<void> {
    const store = this.requireStore();
    const data = playlists.map((p: Playlist) => toStoredPlaylist(p));
    await store.put(CUSTOM_PLAYLISTS_KEY, JSON.stringify(data));
    await store.flush();
  }

  async createPlaylist(name: string): Promise<Playlist[]> {
    const playlists = await this.loadCustomPlaylists();
    const newPlaylist = new PlaylistItem(`local_${Date.now()}`, name);
    const updated: Playlist[] = playlists.concat([newPlaylist]);
    await this.saveCustomPlaylists(updated);
    return updated;
  }

  async deletePlaylist(id: string): Promise<Playlist[]> {
    const playlists = await this.loadCustomPlaylists();
    const updated = playlists.filter((p: Playlist) => p.id !== id);
    await this.saveCustomPlaylists(updated);
    return updated;
  }

  async renamePlaylist(id: string, name: string): Promise<Playlist[]> {
    const playlists = await this.loadCustomPlaylists();
    const updated = playlists.map((p: Playlist) =>
      p.id === id ? new PlaylistItem(p.id, name, p.createdAt, p.songs) : p
    );
    await this.saveCustomPlaylists(updated);
    return updated;
  }

  async addSongToPlaylist(id: string, song: Song): Promise<Playlist[]> {
    const playlists = await this.loadCustomPlaylists();
    const updated = playlists.map((p: Playlist) => {
      if (p.id !== id) {
        return p;
      }
      if (p.songs.some((s: Song) => songKey(s) === songKey(song))) {
        return p;
      }
      return new PlaylistItem(p.id, p.name, p.createdAt, p.songs.concat([song]));
    });
    await this.saveCustomPlaylists(updated);
    return updated;
  }

  async removeSongFromPlaylist(id: string, song: Song): Promise<Playlist[]> {
    const playlists = await this.loadCustomPlaylists();
    const updated = playlists.map((p: Playlist) => {
      if (p.id !== id) {
        return p;
      }
      return new PlaylistItem(
        p.id,
        p.name,
        p.createdAt,
        p.songs.filter((s: Song) => songKey(s) !== songKey(song))
      );
    });
    await this.saveCustomPlaylists(updated);
    return updated;
  }

  async loadSearchHistory(): Promise<string[]> {
    const store = this.requireStore();
    const value = await store.get(SEARCH_HISTORY_KEY, '[]');
    try {
      return JSON.parse(value as string) as string[];
    } catch (e) {
      return [];
    }
  }

  async addSearchHistory(keyword: string): Promise<string[]> {
    const trimmed = keyword.trim();
    if (!trimmed) {
      return await this.loadSearchHistory();
    }
    const history = await this.loadSearchHistory();
    const filtered = history.filter((k: string) => k !== trimmed);
    const updated: string[] = [trimmed].concat(filtered).slice(0, 20);
    const store = this.requireStore();
    await store.put(SEARCH_HISTORY_KEY, JSON.stringify(updated));
    await store.flush();
    return updated;
  }

  async clearSearchHistory(): Promise<void> {
    const store = this.requireStore();
    await store.put(SEARCH_HISTORY_KEY, '[]');
    await store.flush();
  }

  contains(songs: Song[], song: Song): boolean {
    const key = songKey(song);
    return songs.some((item: Song) => songKey(item) === key);
  }

  toggle(songs: Song[], song: Song): Song[] {
    const key = songKey(song);
    if (this.contains(songs, song)) {
      return songs.filter((item: Song) => songKey(item) !== key);
    }
    return songs.concat([song]);
  }

  private defaultSettings(): AppSettings {
    const settings: AppSettings = {
      playMode: 'sequence',
      volume: 0.8,
      theme: 'auto',
      quality: 'high',
      playbackSpeed: 1.0,
      equalizerEnabled: false,
      equalizerPreset: 'flat'
    };
    return settings;
  }

  private async load(key: string): Promise<Song[]> {
    const store = this.requireStore();
    const value = await store.get(key, '[]');
    try {
      const data = JSON.parse(value as string) as StoredSong[];
      return data.map((item: StoredSong): Song => new LocalSong(item));
    } catch (e) {
      return [];
    }
  }

  private async save(key: string, songs: Song[]): Promise<void> {
    const store = this.requireStore();
    const data = songs.map((song: Song): StoredSong => toStoredSong(song));
    await store.put(key, JSON.stringify(data));
    await store.flush();
  }

  private requireStore(): preferences.Preferences {
    if (!this.store) {
      throw new Error('本地音乐库尚未初始化');
    }
    return this.store;
  }
}

export const localMusicLibrary = new LocalMusicLibrary();
