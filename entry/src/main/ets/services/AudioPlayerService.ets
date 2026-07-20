import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';

export type PlayerStateListener = (state: string) => void;
export type PlayerProgressListener = (position: number, duration: number) => void;

export class SongInfo {
  title: string;
  artist: string;
  album: string;
  duration: number;
  position: number;

  constructor(title: string, artist: string, album: string, duration: number, position: number) {
    this.title = title;
    this.artist = artist;
    this.album = album;
    this.duration = duration;
    this.position = position;
  }
}

export class AudioPlayerService {
  private player?: media.AVPlayer;
  private listener?: PlayerStateListener;
  private progressListener?: PlayerProgressListener;
  private currentSongInfo?: SongInfo;
  private generation: number = 0;

  setListener(listener: PlayerStateListener): void {
    this.listener = listener;
  }

  setProgressListener(listener: PlayerProgressListener): void {
    this.progressListener = listener;
  }

  async play(url: string, songInfo?: SongInfo): Promise<void> {
    const generation = ++this.generation;
    await this.releasePlayer();
    if (generation !== this.generation) {
      return;
    }
    const player = await media.createAVPlayer();
    if (generation !== this.generation) {
      await player.release();
      return;
    }
    this.player = player;
    this.currentSongInfo = songInfo;

    player.on('stateChange', (state: string) => {
      if (generation !== this.generation || player !== this.player) {
        return;
      }
      this.listener?.(state);
      if (state === 'initialized') {
        this.prepare(player, generation);
      } else if (state === 'prepared') {
        this.start(player, generation);
      }
    });
    player.on('error', (error: BusinessError) => {
      if (generation === this.generation && player === this.player) {
        this.listener?.(`error: ${error.message}`);
      }
    });
    player.on('timeUpdate', (position: number) => {
      if (generation === this.generation && player === this.player) {
        if (this.currentSongInfo) {
          this.currentSongInfo.position = position;
        }
        this.progressListener?.(position, player.duration);
      }
    });
    player.on('durationUpdate', (duration: number) => {
      if (generation === this.generation && player === this.player) {
        if (this.currentSongInfo) {
          this.currentSongInfo.duration = duration;
        }
        this.progressListener?.(player.currentTime, duration);
      }
    });
    player.url = url;
  }

  private async prepare(player: media.AVPlayer, generation: number): Promise<void> {
    try {
      await player.prepare();
    } catch (error) {
      if (generation === this.generation) {
        this.listener?.(`error: ${this.errorMessage(error)}`);
      }
    }
  }

  private async start(player: media.AVPlayer, generation: number): Promise<void> {
    try {
      await player.play();
    } catch (error) {
      if (generation === this.generation) {
        this.listener?.(`error: ${this.errorMessage(error)}`);
      }
    }
  }

  async toggle(): Promise<void> {
    const player = this.player;
    if (!player) {
      return;
    }
    try {
      if (player.state === 'playing') {
        await player.pause();
      } else if (player.state === 'paused') {
        await player.play();
      } else if (player.state === 'completed') {
        // 修复 bug #3:歌已播完(completed)时,MiniPlayer/FullPlayer 显示"播放"按钮,
        // 此处点播放的语义是"重播当前歌",而非无意义地从末尾继续。先 seek 回开头再 play。
        player.seek(0);
        await player.play();
      }
    } catch (error) {
      this.listener?.(`error: ${this.errorMessage(error)}`);
    }
  }

  async seek(position: number): Promise<void> {
    const player = this.player;
    if (!player || !Number.isFinite(position)) {
      return;
    }
    try {
      player.seek(Math.max(0, position));
    } catch (error) {
      this.listener?.(`error: ${this.errorMessage(error)}`);
    }
  }

  async setVolume(volume: number): Promise<void> {
    const player = this.player;
    if (!player) {
      return;
    }
    try {
      player.setVolume(Math.min(1, Math.max(0, volume)));
    } catch (error) {
      this.listener?.(`error: ${this.errorMessage(error)}`);
    }
  }

  async setSpeed(speed: number): Promise<void> {
    const player = this.player;
    if (!player) {
      return;
    }
    try {
      player.setSpeed(this.mapSpeed(speed));
    } catch (error) {
      this.listener?.(`error: ${this.errorMessage(error)}`);
    }
  }

  private mapSpeed(speed: number): media.PlaybackSpeed {
    // 修复 bug #1: 之前 <=1.5 映射到 1.75x,导致用户选 1.5x 实际播放 1.75x。
    // 现按"向下取整到最接近的档位"映射,1.5x 正确返回 1.50x。
    if (speed <= 0.875) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    }
    if (speed <= 1.125) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    }
    if (speed <= 1.375) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    }
    if (speed <= 1.625) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    }
    if (speed <= 1.875) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    }
    return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
  }

  getCurrentPosition(): number {
    return this.player?.currentTime ?? 0;
  }

  getDuration(): number {
    return this.player?.duration ?? 0;
  }

  getCurrentSongInfo(): SongInfo | undefined {
    return this.currentSongInfo;
  }

  isPlaying(): boolean {
    return this.player?.state === 'playing';
  }

  async release(): Promise<void> {
    this.generation++;
    await this.releasePlayer();
  }

  private async releasePlayer(): Promise<void> {
    const player = this.player;
    this.player = undefined;
    if (!player) {
      return;
    }
    try {
      await player.release();
    } catch (error) {
      this.listener?.(`error: ${this.errorMessage(error)}`);
    }
  }

  private errorMessage(error: Object): string {
    return error instanceof Error ? error.message : `${error}`;
  }
}

export const audioPlayer = new AudioPlayerService();
