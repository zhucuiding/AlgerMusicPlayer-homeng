import { LyricLine, LyricResult, Song } from '../model/MusicModels';
import { musicApi } from './MusicApi';

const LYRIC_CACHE_MAX = 32;

export class LyricService {
  // 修复 bug #14:原先 Map 无上限,长期使用会持续增长。现做简易 LRU,超出上限淘汰最旧条目。
  private cache: Map<string, LyricResult> = new Map();

  async getLyric(song: Song): Promise<LyricResult> {
    const key = `${song.source}:${song.id}`;
    const cached = this.cache.get(key);
    if (cached) {
      // 命中即"重新插入"到末尾,作为最近使用,延长其淘汰时机。
      this.cache.delete(key);
      this.cache.set(key, cached);
      return cached;
    }
    const result = await musicApi.getLyric(song);
    if (result.lines.length > 0) {
      this.evictIfNeeded();
      this.cache.set(key, result);
    }
    return result;
  }

  private evictIfNeeded(): void {
    while (this.cache.size >= LYRIC_CACHE_MAX) {
      let oldestKey: string | undefined = undefined;
      for (const k of this.cache.keys()) {
        oldestKey = k;
        break;
      }
      if (oldestKey === undefined) {
        break;
      }
      this.cache.delete(oldestKey);
    }
  }

  findCurrentLineIndex(lines: LyricLine[], position: number): number {
    if (lines.length === 0) {
      return -1;
    }
    let index = -1;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  clearCache(): void {
    this.cache.clear();
  }
}

export const lyricService = new LyricService();
