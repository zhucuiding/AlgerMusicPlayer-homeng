// ===== 基础数据模型 =====

export interface SearchArtist {
  name: string;
}

export interface SearchAlbum {
  name: string;
  picUrl?: string;
}

export interface Song {
  id: string;
  name: string;
  artists: SearchArtist[];
  source: string;
  album?: SearchAlbum;
  duration?: number;
}

// ===== GD 音乐台 API 响应结构 =====

export interface GdSearchItem {
  id: string;
  name: string;
  artist?: string[];
  album?: string;
  source?: string;
}

export interface GdSongUrlResponse {
  url?: string;
  br?: number;
  size?: number;
}

export interface GdLyricResponse {
  lyric?: string;
  tlyric?: string;
}

export interface GdPlaylistItem {
  id: string;
  name: string;
  coverImgUrl?: string;
  creator?: string;
  trackCount?: number;
  playCount?: number;
}

export interface GdAlbumItem {
  id: string;
  name: string;
  artist?: string;
  coverImgUrl?: string;
  publishTime?: string;
}

export interface GdArtistItem {
  id: string;
  name: string;
  img1v1Url?: string;
  albumSize?: number;
  musicSize?: number;
}

export interface GdPlaylistDetail {
  id: string;
  name: string;
  coverImgUrl?: string;
  description?: string;
  creator?: string;
  tracks: Song[];
}

export interface GdAlbumDetail {
  id: string;
  name: string;
  artist?: string;
  coverImgUrl?: string;
  description?: string;
  tracks: Song[];
}

export interface GdArtistDetail {
  id: string;
  name: string;
  img1v1Url?: string;
  hotSongs: Song[];
  albums: GdAlbumItem[];
}

export interface ToplistEntry {
  id: string;
  name: string;
  coverImgUrl?: string;
  description?: string;
  updateFrequency?: string;
}

export interface HotSearchEntry {
  keyword: string;
  score?: number;
}

export interface DailyRecommendEntry {
  song: Song;
  reason?: string;
}

// ===== Song 实现类 =====

export class SongArtist implements SearchArtist {
  name: string;

  constructor(name: string) {
    this.name = name;
  }
}

export class SongAlbum implements SearchAlbum {
  name: string;
  picUrl?: string;

  constructor(name: string, picUrl?: string) {
    this.name = name;
    this.picUrl = picUrl;
  }
}

export class SearchSong implements Song {
  id: string;
  name: string;
  artists: SearchArtist[];
  source: string;
  album?: SearchAlbum;

  constructor(item: GdSearchItem, fallbackSource: string) {
    this.id = item.id;
    this.name = item.name;
    this.artists = (item.artist ?? []).map((name: string) => new SongArtist(name));
    this.source = item.source ?? fallbackSource;
    this.album = item.album ? new SongAlbum(item.album) : undefined;
  }
}

// ===== 本地持久化结构 =====

export interface StoredSong {
  id: string;
  name: string;
  artists: string[];
  source: string;
  album?: string;
}

export class LocalSong implements Song {
  id: string;
  name: string;
  artists: SearchArtist[];
  source: string;
  album?: SearchAlbum;

  constructor(item: StoredSong) {
    this.id = item.id;
    this.name = item.name;
    this.artists = item.artists.map((name: string) => new SongArtist(name));
    this.source = item.source;
    this.album = item.album ? new SongAlbum(item.album) : undefined;
  }
}

export function toStoredSong(song: Song): StoredSong {
  return {
    id: song.id,
    name: song.name,
    artists: song.artists.map((artist: SearchArtist) => artist.name),
    source: song.source,
    album: song.album?.name
  };
}

export function songKey(song: Song): string {
  return `${song.source}:${song.id}`;
}

// ===== 歌词 =====

export interface LyricLine {
  time: number;
  text: string;
}

export interface LyricResult {
  lines: LyricLine[];
  translation?: LyricLine[];
  hasTranslation: boolean;
}

// ===== 自建歌单 =====

export interface Playlist {
  id: string;
  name: string;
  createdAt: number;
  songs: Song[];
}

export class PlaylistItem implements Playlist {
  id: string;
  name: string;
  createdAt: number;
  songs: Song[];

  constructor(id: string, name: string, createdAt: number = Date.now(), songs: Song[] = []) {
    this.id = id;
    this.name = name;
    this.createdAt = createdAt;
    this.songs = songs;
  }
}

export interface StoredPlaylist {
  id: string;
  name: string;
  createdAt: number;
  songs: StoredSong[];
}

export function toStoredPlaylist(playlist: Playlist): StoredPlaylist {
  return {
    id: playlist.id,
    name: playlist.name,
    createdAt: playlist.createdAt,
    songs: playlist.songs.map((song: Song) => toStoredSong(song))
  };
}

export function toPlaylist(stored: StoredPlaylist): PlaylistItem {
  return new PlaylistItem(
    stored.id,
    stored.name,
    stored.createdAt,
    stored.songs.map((s: StoredSong) => new LocalSong(s))
  );
}

// ===== 播放历史 =====

export interface HistoryEntry {
  song: Song;
  playedAt: number;
}

export interface StoredHistoryEntry {
  id: string;
  name: string;
  artists: string[];
  source: string;
  album?: string;
  playedAt: number;
}

export function toStoredHistory(entry: HistoryEntry): StoredHistoryEntry {
  return {
    id: entry.song.id,
    name: entry.song.name,
    artists: entry.song.artists.map((a: SearchArtist) => a.name),
    source: entry.song.source,
    album: entry.song.album?.name,
    playedAt: entry.playedAt
  };
}

export function toHistoryEntry(stored: StoredHistoryEntry): HistoryEntry {
  return {
    song: new LocalSong({
      id: stored.id,
      name: stored.name,
      artists: stored.artists,
      source: stored.source,
      album: stored.album
    }),
    playedAt: stored.playedAt
  };
}

// ===== 应用设置 =====

export interface AppSettings {
  playMode: string;
  volume: number;
  theme: 'auto' | 'light' | 'dark';
  quality: 'standard' | 'high' | 'lossless';
  playbackSpeed: number;
  equalizerEnabled: boolean;
  equalizerPreset: string;
}
