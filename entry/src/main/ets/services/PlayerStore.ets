import { common } from '@kit.AbilityKit';
import { Song, songKey, HistoryEntry, Playlist, SearchArtist, AppSettings } from '../model/MusicModels';
import { audioPlayer, SongInfo } from './AudioPlayerService';
import { musicApi } from './MusicApi';
import { localMusicLibrary } from './LocalMusicLibrary';
import { lyricService } from './LyricService';
import { sleepTimer } from './SleepTimer';
import { equalizer } from './EqualizerService';
import { themeService } from './ThemeService';
import { LyricLine } from '../model/MusicModels';

export type PlayerStoreListener = () => void;

class PlayerStoreClass {
  currentSong: Song | null = null;
  queue: Song[] = [];
  queueIndex: number = -1;
  playerState: string = 'idle';
  position: number = 0;
  duration: number = 0;
  volume: number = 0.8;
  playMode: string = 'sequence';
  shuffle: boolean = false;
  quality: string = 'high';
  playbackSpeed: number = 1.0;
  lyricLines: LyricLine[] = [];
  currentLyricIndex: number = -1;
  favorites: Song[] = [];
  collection: Song[] = [];
  history: HistoryEntry[] = [];
  customPlaylists: Playlist[] = [];
  searchHistory: string[] = [];
  libraryReady: boolean = false;
  sleepRemaining: number = 0;
  sleepActive: boolean = false;

  private listeners: Set<PlayerStoreListener> = new Set();
  private playGeneration: number = 0;

  constructor() {
    audioPlayer.setListener((state: string) => {
      this.playerState = state;
      if (state === 'completed') {
        this.playNext();
      }
      this.notify();
    });
    audioPlayer.setProgressListener((pos: number, dur: number) => {
      this.position = pos;
      this.duration = dur;
      const oldIndex = this.currentLyricIndex;
      this.updateLyricIndex();
      // 仅在歌词行变化或时长变化时通知，避免每秒高频重绘
      if (oldIndex !== this.currentLyricIndex || dur !== this.duration) {
        this.notify();
      }
    });
    sleepTimer.setListener((remaining: number, active: boolean) => {
      this.sleepRemaining = remaining;
      this.sleepActive = active;
      this.notify();
    });
    sleepTimer.setEndListener(() => {
      audioPlayer.toggle();
      this.notify();
    });
  }

  subscribe(listener: PlayerStoreListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify(): void {
    this.listeners.forEach((l: PlayerStoreListener) => l());
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    try {
      await localMusicLibrary.initialize(context);
      this.favorites = await localMusicLibrary.loadFavorites();
      this.collection = await localMusicLibrary.loadCollection();
      this.queue = await localMusicLibrary.loadPlaylist();
      this.history = await localMusicLibrary.loadHistory();
      this.customPlaylists = await localMusicLibrary.loadCustomPlaylists();
      this.searchHistory = await localMusicLibrary.loadSearchHistory();
      const settings = await localMusicLibrary.loadSettings();
      this.playMode = settings.playMode;
      this.shuffle = settings.playMode === 'shuffle';
      this.volume = settings.volume;
      this.quality = settings.quality;
      this.playbackSpeed = settings.playbackSpeed;
      equalizer.setEnabled(settings.equalizerEnabled);
      equalizer.applyPreset(settings.equalizerPreset);
      // 修复 bug #8:重启后从持久化设置恢复主题模式,并立即应用到窗口。
      themeService.setMode(settings.theme);
      themeService.apply(context);
      this.libraryReady = true;
      this.notify();
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      console.error('PlayerStore init failed: ' + msg);
    }
  }

  async playSong(song: Song, queue?: Song[]): Promise<void> {
    const generation = ++this.playGeneration;
    if (queue && queue.length > 0) {
      // 修复 bug #6:歌单详情"全部播放"传入的列表可能含重复 songKey,
      // 导致 findIndex 命中第一个、后续切歌顺序错乱。这里按 songKey 去重(保留首次出现)。
      const seen: Set<string> = new Set<string>();
      const deduped: Song[] = [];
      for (const s of queue) {
        const k = songKey(s);
        if (!seen.has(k)) {
          seen.add(k);
          deduped.push(s);
        }
      }
      this.queue = deduped;
      this.queueIndex = deduped.findIndex((s: Song) => songKey(s) === songKey(song));
      if (this.queueIndex < 0) {
        this.queue = [song].concat(this.queue);
        this.queueIndex = 0;
      }
    } else if (this.queue.length === 0) {
      this.queue = [song];
      this.queueIndex = 0;
    } else {
      const idx = this.queue.findIndex((s: Song) => songKey(s) === songKey(song));
      if (idx >= 0) {
        this.queueIndex = idx;
      } else {
        this.queue = [song].concat(this.queue);
        this.queueIndex = 0;
      }
    }
    this.currentSong = song;
    this.playerState = 'loading';
    this.position = 0;
    this.duration = 0;
    this.lyricLines = [];
    this.currentLyricIndex = -1;
    this.notify();

    try {
      const url = await musicApi.getSongUrl(song, this.quality);
      if (generation !== this.playGeneration) {
        return;
      }
      const artistNames: string = song.artists.map((a: SearchArtist) => a.name).join(' / ');
      const albumName: string = song.album?.name ?? '';
      const info: SongInfo = new SongInfo(song.name, artistNames, albumName, 0, 0);
      await audioPlayer.play(url, info);
      if (generation !== this.playGeneration) {
        return;
      }
      if (this.playbackSpeed !== 1.0) {
        await audioPlayer.setSpeed(this.playbackSpeed);
      }
      await audioPlayer.setVolume(this.volume);
      this.history = await localMusicLibrary.addHistory(song);
      this.loadLyric(song);
      this.notify();
    } catch (error) {
      if (generation === this.playGeneration) {
        const msg = error instanceof Error ? error.message : `${error}`;
        this.playerState = `播放失败：${msg}`;
        this.notify();
      }
    }
  }

  private async loadLyric(song: Song): Promise<void> {
    try {
      const result = await lyricService.getLyric(song);
      this.lyricLines = result.lines;
      this.updateLyricIndex();
      this.notify();
    } catch (error) {
      this.lyricLines = [];
    }
  }

  private updateLyricIndex(): void {
    if (this.lyricLines.length === 0) {
      this.currentLyricIndex = -1;
      return;
    }
    let idx = -1;
    for (let i = 0; i < this.lyricLines.length; i++) {
      if (this.lyricLines[i].time <= this.position) {
        idx = i;
      } else {
        break;
      }
    }
    this.currentLyricIndex = idx;
  }

  async togglePlay(): Promise<void> {
    await audioPlayer.toggle();
  }

  // 修复 bug #4:串行化切歌操作,防止 completed 回调与用户手动点击并发导致跳两首。
  private nextChain: Promise<void> = Promise.resolve();

  async playNext(): Promise<void> {
    this.nextChain = this.nextChain.then(() => this.doPlayNext());
    return this.nextChain;
  }

  private async doPlayNext(): Promise<void> {
    if (this.queue.length === 0) {
      return;
    }
    if (this.playMode === 'single' && this.queueIndex >= 0) {
      const song = this.queue[this.queueIndex];
      if (song) {
        await this.playSong(song);
      }
      return;
    }
    if (this.shuffle) {
      const idx = Math.floor(Math.random() * this.queue.length);
      this.queueIndex = idx;
      await this.playSong(this.queue[idx]);
      return;
    }
    const next = this.queueIndex < 0 ? 0 : (this.queueIndex + 1) % this.queue.length;
    this.queueIndex = next;
    await this.playSong(this.queue[next]);
  }

  async playPrevious(): Promise<void> {
    if (this.queue.length === 0) {
      return;
    }
    const prev = this.queueIndex <= 0 ? this.queue.length - 1 : this.queueIndex - 1;
    this.queueIndex = prev;
    await this.playSong(this.queue[prev]);
  }

  async seek(position: number): Promise<void> {
    await audioPlayer.seek(position);
  }

  async setVolume(volume: number): Promise<void> {
    this.volume = volume;
    await audioPlayer.setVolume(volume);
    await this.saveSettings();
    this.notify();
  }

  async setPlayMode(mode: string): Promise<void> {
    this.playMode = mode;
    this.shuffle = mode === 'shuffle';
    await this.saveSettings();
    this.notify();
  }

  async setQuality(quality: string): Promise<void> {
    this.quality = quality;
    await this.saveSettings();
    this.notify();
  }

  async setPlaybackSpeed(speed: number): Promise<void> {
    this.playbackSpeed = speed;
    await audioPlayer.setSpeed(speed);
    await this.saveSettings();
    this.notify();
  }

  async saveSettings(): Promise<void> {
    if (!this.libraryReady) {
      return;
    }
    // 修复 bug #8:之前 theme 永远硬编码 'auto',导致用户选的浅色/深色不持久化。
    // 现在存 themeService 的实际模式。
    const themeValue: 'auto' | 'light' | 'dark' = themeService.getMode();
    const settings: AppSettings = {
      playMode: this.playMode,
      volume: this.volume,
      theme: themeValue,
      quality: this.quality as 'standard' | 'high' | 'lossless',
      playbackSpeed: this.playbackSpeed,
      equalizerEnabled: equalizer.isEnabled(),
      equalizerPreset: equalizer.getCurrentPreset()
    };
    await localMusicLibrary.saveSettings(settings);
  }

  isFavorite(song: Song): boolean {
    return localMusicLibrary.contains(this.favorites, song);
  }

  async toggleFavorite(song: Song): Promise<void> {
    this.favorites = localMusicLibrary.toggle(this.favorites, song);
    await localMusicLibrary.saveFavorites(this.favorites);
    this.notify();
  }

  isCollected(song: Song): boolean {
    return localMusicLibrary.contains(this.collection, song);
  }

  async toggleCollection(song: Song): Promise<void> {
    this.collection = localMusicLibrary.toggle(this.collection, song);
    await localMusicLibrary.saveCollection(this.collection);
    this.notify();
  }

  isInQueue(song: Song): boolean {
    return localMusicLibrary.contains(this.queue, song);
  }

  async toggleQueue(song: Song): Promise<void> {
    this.queue = localMusicLibrary.toggle(this.queue, song);
    await localMusicLibrary.savePlaylist(this.queue);
    if (this.queueIndex >= this.queue.length) {
      this.queueIndex = this.queue.length - 1;
    }
    this.notify();
  }

  async clearQueue(): Promise<void> {
    this.queue = [];
    this.queueIndex = -1;
    await localMusicLibrary.savePlaylist(this.queue);
    this.notify();
  }

  removeFromQueue(index: number): void {
    if (index < 0 || index >= this.queue.length) {
      return;
    }
    this.queue.splice(index, 1);
    if (this.queueIndex === index) {
      this.queueIndex = -1;
    } else if (this.queueIndex > index) {
      this.queueIndex--;
    }
    localMusicLibrary.savePlaylist(this.queue);
    this.notify();
  }

  async clearHistory(): Promise<void> {
    await localMusicLibrary.clearHistory();
    this.history = [];
    this.notify();
  }

  async createPlaylist(name: string): Promise<void> {
    this.customPlaylists = await localMusicLibrary.createPlaylist(name);
    this.notify();
  }

  async deletePlaylist(id: string): Promise<void> {
    this.customPlaylists = await localMusicLibrary.deletePlaylist(id);
    this.notify();
  }

  async renamePlaylist(id: string, name: string): Promise<void> {
    this.customPlaylists = await localMusicLibrary.renamePlaylist(id, name);
    this.notify();
  }

  async addSongToPlaylist(id: string, song: Song): Promise<void> {
    this.customPlaylists = await localMusicLibrary.addSongToPlaylist(id, song);
    this.notify();
  }

  async removeSongFromPlaylist(id: string, song: Song): Promise<void> {
    this.customPlaylists = await localMusicLibrary.removeSongFromPlaylist(id, song);
    this.notify();
  }

  async addSearchHistory(keyword: string): Promise<void> {
    this.searchHistory = await localMusicLibrary.addSearchHistory(keyword);
    this.notify();
  }

  async clearSearchHistory(): Promise<void> {
    await localMusicLibrary.clearSearchHistory();
    this.searchHistory = [];
    this.notify();
  }

  startSleepTimer(durationMs: number): void {
    sleepTimer.start(durationMs);
  }

  cancelSleepTimer(): void {
    sleepTimer.cancel();
  }

  formatTime(milliseconds: number): string {
    const seconds = Math.floor(Math.max(0, milliseconds) / 1000);
    const minutes = Math.floor(seconds / 60).toString().padStart(2, '0');
    const remainder = (seconds % 60).toString().padStart(2, '0');
    return `${minutes}:${remainder}`;
  }
}

export const playerStore = new PlayerStoreClass();

