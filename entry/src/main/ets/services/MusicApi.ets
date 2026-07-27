import { http } from '@kit.NetworkKit';
import {
  GdSearchItem,
  GdSongUrlResponse,
  GdLyricResponse,
  GdPlaylistItem,
  GdAlbumItem,
  GdArtistItem,
  GdPlaylistDetail,
  GdAlbumDetail,
  GdArtistDetail,
  ToplistEntry,
  HotSearchEntry,
  DailyRecommendEntry,
  SearchSong,
  Song,
  SongArtist,
  SongAlbum,
  SearchArtist,
  LyricResult,
  LyricLine
} from '../model/MusicModels';

const API_BASE = 'https://music-api.gdstudio.xyz/api.php';
const REQUEST_TIMEOUT = 15000;
const SEARCH_SOURCES: string[] = ['netease', 'joox', 'tidal'];
const SEARCH_CACHE_MAX = 20;

export interface QualityMap {
  standard: number;
  high: number;
  lossless: number;
}

export const QUALITY_BR: QualityMap = {
  standard: 128,
  high: 320,
  lossless: 999
};

export function qualityBitrate(quality: string): number {
  if (quality === 'standard') {
    return QUALITY_BR.standard;
  }
  if (quality === 'lossless') {
    return QUALITY_BR.lossless;
  }
  return QUALITY_BR.high;
}

export interface ToplistResponseItem {
  id?: string | number;
  name?: string;
  coverImgUrl?: string;
  picUrl?: string;
  description?: string;
  updateFrequency?: string;
}

export interface ArtistNameRef {
  name?: string;
}

export interface PlaylistTrackItem {
  id?: string | number;
  name?: string;
  artists?: ArtistNameRef[];
  album?: AlbumRef;
  duration?: number;
}

export interface AlbumRef {
  name?: string;
  picUrl?: string;
}

export interface PlaylistCreator {
  name?: string;
}

export interface PlaylistDetailResponse {
  id?: string | number;
  name?: string;
  coverImgUrl?: string;
  picUrl?: string;
  description?: string;
  creator?: PlaylistCreator | string;
  tracks?: PlaylistTrackItem[];
  playlists?: PlaylistTrackItem[];
  playlist?: PlaylistDetailResponse;
}

export interface AlbumTrackItem {
  id?: string | number;
  name?: string;
  artists?: ArtistNameRef[];
  duration?: number;
}

export interface AlbumArtist {
  name?: string;
}

export interface AlbumDetailResponse {
  id?: string | number;
  name?: string;
  artist?: AlbumArtist | string;
  picUrl?: string;
  coverImgUrl?: string;
  description?: string;
  songs?: AlbumTrackItem[];
}

export interface ArtistHotSongItem {
  id?: string | number;
  name?: string;
  artists?: ArtistNameRef[];
  album?: AlbumRef;
  duration?: number;
}

export interface ArtistAlbumItem {
  id?: string | number;
  name?: string;
  picUrl?: string;
  coverImgUrl?: string;
  publishTime?: number | string;
}

export interface ArtistDetailResponse {
  id?: string | number;
  name?: string;
  img1v1Url?: string;
  picUrl?: string;
  hotSongs?: ArtistHotSongItem[];
  songs?: ArtistHotSongItem[];
  hotAlbums?: ArtistAlbumItem[];
  albums?: ArtistAlbumItem[];
}

export interface HotSearchResponseItem {
  searchWord?: string;
  keyword?: string;
  first?: string;
  score?: number;
}

export class MusicApi {
  async search(keywords: string, source?: string): Promise<Song[]> {
    const cacheKey = `${source ?? 'auto'}:${keywords.trim().toLowerCase()}`;
    const cached = this.searchCache.get(cacheKey);
    if (cached) {
      this.searchCache.delete(cacheKey);
      this.searchCache.set(cacheKey, cached);
      return cached;
    }
    const pending = this.searchRequests.get(cacheKey);
    if (pending) {
      return pending;
    }
    const request = this.searchFromSources(keywords, source);
    this.searchRequests.set(cacheKey, request);
    try {
      const songs = await request;
      if (songs.length > 0) {
        while (this.searchCache.size >= SEARCH_CACHE_MAX) {
          const oldest = this.searchCache.keys().next().value as string | undefined;
          if (!oldest) {
            break;
          }
          this.searchCache.delete(oldest);
        }
        this.searchCache.set(cacheKey, songs);
      }
      return songs;
    } finally {
      this.searchRequests.delete(cacheKey);
    }
  }

  private searchCache: Map<string, Song[]> = new Map();
  private searchRequests: Map<string, Promise<Song[]>> = new Map();

  private async searchFromSources(keywords: string, source?: string): Promise<Song[]> {
    const sources = source ? [source] : SEARCH_SOURCES;
    let lastError: Error | undefined;
    for (const src of sources) {
      try {
        const result = await this.getJson<GdSearchItem[]>(
          `?types=search&source=${src}&name=${encodeURIComponent(keywords)}&count=30&pages=1`
        );
        if (result.length > 0) {
          return result.map((item: GdSearchItem): Song => new SearchSong(item, src));
        }
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(`${error}`);
      }
    }
    if (lastError) {
      throw lastError;
    }
    return [];
  }

  async getSongUrl(song: Song, quality: string = 'high'): Promise<string> {
    const requested = qualityBitrate(quality);
    const bitrates: number[] = requested === QUALITY_BR.lossless ?
      [QUALITY_BR.lossless, QUALITY_BR.high, QUALITY_BR.standard] :
      requested === QUALITY_BR.high ? [QUALITY_BR.high, QUALITY_BR.standard] : [QUALITY_BR.standard];
    let lastError: Error | undefined;
    for (const br of bitrates) {
      try {
        const result = await this.getJson<GdSongUrlResponse>(
          `?types=url&source=${encodeURIComponent(song.source)}&id=${encodeURIComponent(song.id)}&br=${br}`
        );
        if (result.url && (result.url.startsWith('http://') || result.url.startsWith('https://'))) {
          return result.url;
        }
        lastError = new Error('该音源没有返回可用播放地址');
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(`${error}`);
      }
    }
    throw lastError ?? new Error('无法获取播放地址');
  }

  async getLyric(song: Song): Promise<LyricResult> {
    try {
      const result = await this.getJson<GdLyricResponse>(
        `?types=lyric&source=${encodeURIComponent(song.source)}&id=${encodeURIComponent(song.id)}`
      );
      const lines = this.parseLrc(result.lyric ?? '');
      const translation = result.tlyric ? this.parseLrc(result.tlyric) : [];
      const lyricResult: LyricResult = {
        lines,
        translation: translation.length > 0 ? translation : undefined,
        hasTranslation: translation.length > 0
      };
      return lyricResult;
    } catch (error) {
      const emptyResult: LyricResult = { lines: [], hasTranslation: false };
      return emptyResult;
    }
  }

  private parseLrc(lrcText: string): LyricLine[] {
    const lines: LyricLine[] = [];
    const timeRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/g;
    const textLines = lrcText.split('\n');
    for (const line of textLines) {
      const matches = Array.from(line.matchAll(timeRegex));
      const text = line.replace(timeRegex, '').trim();
      if (!text) {
        continue;
      }
      for (const match of matches) {
        const min = parseInt(match[1], 10);
        const sec = parseInt(match[2], 10);
        const ms = parseInt(match[3].padEnd(3, '0'), 10);
        const time = min * 60 * 1000 + sec * 1000 + ms;
        const lyricLine: LyricLine = { time, text };
        lines.push(lyricLine);
      }
    }
    lines.sort((a: LyricLine, b: LyricLine) => a.time - b.time);
    return lines;
  }

  async getToplists(source: string = 'netease'): Promise<ToplistEntry[]> {
    const featuredPlaylistIds: ToplistEntry[] = [
      { id: '3778678', name: '飙升榜', updateFrequency: '每日更新' },
      { id: '3779629', name: '新歌榜', updateFrequency: '每日更新' },
      { id: '19723756', name: '热歌榜', updateFrequency: '每周更新' },
      { id: '60198', name: '华语金曲榜', updateFrequency: '每周更新' },
      { id: '180106', name: 'UK排行榜', updateFrequency: '每周更新' }
    ];
    return featuredPlaylistIds;
  }

  async getPlaylistDetail(id: string, source: string = 'netease'): Promise<GdPlaylistDetail | null> {
    try {
      const result = await this.getJson<PlaylistDetailResponse>(
        `?types=playlist&id=${encodeURIComponent(id)}&source=${source}`
      );
      const pl: PlaylistDetailResponse | undefined = result.playlist ?? result;
      const tracksRaw: PlaylistTrackItem[] = pl?.tracks ?? [];
      const tracks: Song[] = tracksRaw.map((item: PlaylistTrackItem): Song => {
        const artists: SearchArtist[] = (item.artists ?? []).map((a: ArtistNameRef): SongArtist => new SongArtist(a.name ?? ''));
        const song: Song = {
          id: `${item.id ?? ''}`,
          name: item.name ?? '',
          artists,
          source: source,
          album: item.album ? new SongAlbum(item.album.name ?? '', item.album.picUrl) : undefined,
          duration: item.duration
        };
        return song;
      });
      const creatorRaw: PlaylistCreator | string | undefined = pl?.creator;
      let creatorName: string = '';
      if (typeof creatorRaw === 'string') {
        creatorName = creatorRaw;
      } else if (creatorRaw !== undefined && creatorRaw !== null) {
        const creatorObj: PlaylistCreator = creatorRaw;
        creatorName = creatorObj.name ?? '';
      }
      const detail: GdPlaylistDetail = {
        id: `${pl?.id ?? id}`,
        name: pl?.name ?? '',
        coverImgUrl: pl?.coverImgUrl ?? pl?.picUrl,
        description: pl?.description,
        creator: creatorName,
        tracks
      };
      return detail;
    } catch (error) {
      return null;
    }
  }

  async getAlbumDetail(id: string, source: string = 'netease'): Promise<GdAlbumDetail | null> {
    try {
      const result = await this.getJson<AlbumDetailResponse>(
        `?types=album&id=${encodeURIComponent(id)}&source=${source}`
      );
      const tracksRaw: AlbumTrackItem[] = result.songs ?? [];
      const tracks: Song[] = tracksRaw.map((item: AlbumTrackItem): Song => {
        const artists: SearchArtist[] = (item.artists ?? []).map((a: ArtistNameRef): SongArtist => new SongArtist(a.name ?? ''));
        const song: Song = {
          id: `${item.id ?? ''}`,
          name: item.name ?? '',
          artists,
          source: source,
          album: new SongAlbum(result.name ?? '', result.picUrl ?? result.coverImgUrl),
          duration: item.duration
        };
        return song;
      });
      const artistRaw: AlbumArtist | string | undefined = result.artist;
      let artistName: string = '';
      if (typeof artistRaw === 'string') {
        artistName = artistRaw;
      } else if (artistRaw !== undefined && artistRaw !== null) {
        const artistObj: AlbumArtist = artistRaw;
        artistName = artistObj.name ?? '';
      }
      const detail: GdAlbumDetail = {
        id: `${result.id ?? id}`,
        name: result.name ?? '',
        artist: artistName,
        coverImgUrl: result.picUrl ?? result.coverImgUrl,
        description: result.description,
        tracks
      };
      return detail;
    } catch (error) {
      return null;
    }
  }

  async getArtistDetail(id: string, source: string = 'netease'): Promise<GdArtistDetail | null> {
    try {
      const result = await this.getJson<ArtistDetailResponse>(
        `?types=artist&id=${encodeURIComponent(id)}&source=${source}`
      );
      const hotRaw: ArtistHotSongItem[] = result.hotSongs ?? result.songs ?? [];
      const hotSongs: Song[] = hotRaw.map((item: ArtistHotSongItem): Song => {
        const artists: SearchArtist[] = (item.artists ?? []).map((a: ArtistNameRef): SongArtist => new SongArtist(a.name ?? ''));
        const song: Song = {
          id: `${item.id ?? ''}`,
          name: item.name ?? '',
          artists,
          source: source,
          album: item.album ? new SongAlbum(item.album.name ?? '', item.album.picUrl) : undefined,
          duration: item.duration
        };
        return song;
      });
      const albumsRaw: ArtistAlbumItem[] = result.hotAlbums ?? result.albums ?? [];
      const albums: GdAlbumItem[] = albumsRaw.map((item: ArtistAlbumItem): GdAlbumItem => {
        const albumItem: GdAlbumItem = {
          id: `${item.id ?? ''}`,
          name: item.name ?? '',
          artist: result.name ?? '',
          coverImgUrl: item.picUrl ?? item.coverImgUrl,
          publishTime: item.publishTime ? new Date(item.publishTime).toLocaleDateString() : undefined
        };
        return albumItem;
      });
      const detail: GdArtistDetail = {
        id: `${result.id ?? id}`,
        name: result.name ?? '',
        img1v1Url: result.img1v1Url ?? result.picUrl,
        hotSongs,
        albums
      };
      return detail;
    } catch (error) {
      return null;
    }
  }

  async getHotSearch(source: string = 'netease'): Promise<HotSearchEntry[]> {
    const hotKeywords: HotSearchEntry[] = [
      { keyword: '周杰伦' },
      { keyword: '林俊杰' },
      { keyword: '陈奕迅' },
      { keyword: '邓紫棋' },
      { keyword: '薛之谦' },
      { keyword: '毛不易' },
      { keyword: '华晨宇' },
      { keyword: '张学友' },
      { keyword: '王菲' },
      { keyword: '李荣浩' }
    ];
    return hotKeywords;
  }

  async getDailyRecommend(source: string = 'netease'): Promise<DailyRecommendEntry[]> {
    try {
      const detail = await this.getPlaylistDetail('3778678', source);
      if (detail && detail.tracks.length > 0) {
        const songs: Song[] = detail.tracks.slice(0, 6);
        const entries: DailyRecommendEntry[] = songs.map((song: Song): DailyRecommendEntry => {
          const entry: DailyRecommendEntry = { song, reason: '飙升榜推荐' };
          return entry;
        });
        return entries;
      }
      return [];
    } catch (error) {
      return [];
    }
  }

  private async getJson<T>(path: string): Promise<T> {
    const client = http.createHttp();
    try {
      const response = await client.request(`${API_BASE}${path}`, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        connectTimeout: REQUEST_TIMEOUT,
        readTimeout: REQUEST_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      return JSON.parse(response.result as string) as T;
    } finally {
      client.destroy();
    }
  }
}

export const musicApi = new MusicApi();
