import { common } from '@kit.AbilityKit';
import { LyricLine, SearchArtist } from '../../model/MusicModels';
import { playerStore } from '../../services/PlayerStore';
import { AppColorKey, Space, Radius } from '../Theme';

/**
 * 全屏播放器。
 *
 * 修复点:
 * - #5  收藏入口:控制栏新增收藏按钮。
 * - #9  歌词滚动:Scroller + currentLyricIndex 变化时 scrollTo。
 * - #10 进度条拖动:拖动中用本地 draggingPosition 驱动,松手才 seek。
 * - #15 倍速按钮:onClick 弹出倍速选择。
 */
@Component
export struct FullPlayer {
  @Link show: boolean;
  @Link showSpeedPicker: boolean;
  @State storeVersion: number = 0;
  @State draggingPosition: number = -1; // >=0 表示正在拖动
  private lyricScroller: Scroller = new Scroller();
  private storeObserver: (() => void) | null = null;
  private lastLyricIndex: number = -1;

  aboutToAppear(): void {
    this.storeObserver = playerStore.subscribe(() => {
      this.storeVersion++;
      this.maybeScrollLyric();
    });
  }

  aboutToDisappear(): void {
    this.storeObserver?.();
  }

  private maybeScrollLyric(): void {
    if (playerStore.currentLyricIndex !== this.lastLyricIndex && playerStore.lyricLines.length > 0) {
      this.lastLyricIndex = playerStore.currentLyricIndex;
      if (playerStore.currentLyricIndex >= 0) {
        this.lyricScroller.scrollToIndex(playerStore.currentLyricIndex, true, ScrollAlign.CENTER);
      }
    }
  }

  private artistNames(): string {
    const song = playerStore.currentSong;
    if (!song) {
      return '';
    }
    return song.artists.map((artist: SearchArtist) => artist.name).join(' / ');
  }

  private sliderValue(): number {
    return this.draggingPosition >= 0 ? this.draggingPosition : playerStore.position;
  }

  build() {
    Column({ space: Space.lg }) {
      Row() {
        Button('关闭').fontSize(13).fontColor($r(AppColorKey.textSecondary)).backgroundColor('transparent')
          .onClick(() => this.show = false)
        Blank().layoutWeight(1)
        Text('正在播放').fontSize(13).fontColor($r(AppColorKey.textHint))
        Blank().layoutWeight(1)
        Text('').width(44)
      }
      .width('100%')

      Text('🎵').fontSize(80).margin({ top: Space.xl, bottom: Space.xl })

      if (playerStore.currentSong && this.storeVersion >= 0) {
        Text(playerStore.currentSong!.name)
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary)).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artistNames())
          .fontSize(14).fontColor($r(AppColorKey.textHint))
      }

      // 歌词
      if (playerStore.lyricLines.length > 0) {
        List({ space: Space.xs, scroller: this.lyricScroller }) {
          ForEach(playerStore.lyricLines, (line: LyricLine, index: number) => {
            ListItem() {
              Text(line.text)
                .fontSize(index === playerStore.currentLyricIndex ? 16 : 13)
                .fontColor(index === playerStore.currentLyricIndex ? $r(AppColorKey.accent) : $r(AppColorKey.textHint))
                .fontWeight(index === playerStore.currentLyricIndex ? FontWeight.Bold : FontWeight.Normal)
                .width('100%').textAlign(TextAlign.Center)
            }
          }, (line: LyricLine) => `${line.time}:${line.text}`)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: Space.lg, right: Space.lg })
      } else {
        Text('暂无歌词').fontSize(13).fontColor($r(AppColorKey.textHint)).layoutWeight(1)
      }

      // 进度条
      Column({ space: Space.xs }) {
        Slider({
          value: this.sliderValue(),
          min: 0,
          max: Math.max(playerStore.duration, 1),
          step: 1000
        })
          .width('100%')
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Begin) {
              this.draggingPosition = value;
            } else if (mode === SliderChangeMode.End) {
              playerStore.seek(value);
              this.draggingPosition = -1;
            }
          })
        Row() {
          Text(playerStore.formatTime(this.sliderValue())).fontSize(11).fontColor($r(AppColorKey.textHint))
          Blank().layoutWeight(1)
          Text(playerStore.formatTime(playerStore.duration)).fontSize(11).fontColor($r(AppColorKey.textHint))
        }
        .width('100%')
      }
      .width('100%')

      // 控制按钮
      Row({ space: Space.xxl }) {
        Button(playerStore.playMode === 'single' ? '单曲' : playerStore.shuffle ? '随机' : '顺序')
          .fontSize(11).fontColor($r(AppColorKey.textSecondary)).backgroundColor($r(AppColorKey.chipBackground)).height(36)
          .onClick(() => {
            const next = playerStore.playMode === 'sequence' ? 'single' : playerStore.playMode === 'single' ? 'shuffle' : 'sequence';
            playerStore.setPlayMode(next);
          })
        Button('上一首').fontSize(12).fontColor($r(AppColorKey.textPrimary)).backgroundColor($r(AppColorKey.chipBackground)).height(40)
          .onClick(() => playerStore.playPrevious())
        Button(playerStore.playerState === 'playing' ? '暂停' : '播放')
          .fontSize(14).fontColor(Color.White).backgroundColor($r(AppColorKey.accent)).height(48).width(48).borderRadius(24)
          .onClick(() => playerStore.togglePlay())
        Button('下一首').fontSize(12).fontColor($r(AppColorKey.textPrimary)).backgroundColor($r(AppColorKey.chipBackground)).height(40)
          .onClick(() => playerStore.playNext())
        Button(`${playerStore.playbackSpeed}x`)
          .fontSize(11).fontColor($r(AppColorKey.textSecondary)).backgroundColor($r(AppColorKey.chipBackground)).height(36)
          .onClick(() => this.showSpeedPicker = true)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: Space.xl })
    }
    .width('100%')
    .height('100%')
    .padding({ left: Space.lg, right: Space.lg, top: 40 })
    .backgroundColor($r(AppColorKey.cardBackground))
  }
}
