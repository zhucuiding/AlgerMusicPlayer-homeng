import { Song, SearchArtist } from '../../model/MusicModels';
import { playerStore } from '../../services/PlayerStore';
import { AppColorKey, Space, Radius, CardBorder, SongRowPadding } from '../Theme';

/**
 * 歌曲行组件。
 *
 * 自包含:直接读写 playerStore 的收藏/队列状态,点击整行即播放。
 * 替代原先散落在 Index.ets 内部的 @Builder SongRow,供 Home/Search/Mine/PlaylistDetail 复用。
 */
@Component
export struct SongCard {
  @Prop song: Song;
  @State storeVersion: number = 0;

  aboutToAppear(): void {
    this.observer = playerStore.subscribe(() => {
      this.storeVersion++;
    });
  }

  aboutToDisappear(): void {
    this.observer?.();
  }

  private observer: (() => void) | null = null;

  private artistNames(): string {
    return this.song.artists.map((artist: SearchArtist) => artist.name).join(' / ');
  }

  build() {
    Row({ space: Space.lg }) {
      Column({ space: Space.xs }) {
        Text(this.song.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r(AppColorKey.textPrimary))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artistNames())
          .fontSize(12)
          .fontColor($r(AppColorKey.textHint))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button(playerStore.isFavorite(this.song) ? '♥' : '♡')
        .type(ButtonType.Circle)
        .fontSize(16)
        .fontColor(playerStore.isFavorite(this.song) ? $r(AppColorKey.accent) : $r(AppColorKey.textSecondary))
        .width(32).height(32)
        .backgroundColor($r(AppColorKey.chipBackground))
        .enabled(playerStore.libraryReady)
        .onClick(() => playerStore.toggleFavorite(this.song))
      // 修复 bug #5:补齐"收藏"入口(原先 collection 有读写逻辑但 UI 无入口,数字永远为 0)。
      Button(playerStore.isCollected(this.song) ? '★' : '☆')
        .type(ButtonType.Circle)
        .fontSize(14)
        .fontColor(playerStore.isCollected(this.song) ? $r(AppColorKey.accent) : $r(AppColorKey.textSecondary))
        .width(32).height(32)
        .backgroundColor($r(AppColorKey.chipBackground))
        .enabled(playerStore.libraryReady)
        .onClick(() => playerStore.toggleCollection(this.song))
      Button(playerStore.isInQueue(this.song) ? '✓' : '＋')
        .type(ButtonType.Circle)
        .fontSize(14)
        .fontColor(playerStore.isInQueue(this.song) ? $r(AppColorKey.accent) : $r(AppColorKey.textSecondary))
        .width(32).height(32)
        .backgroundColor($r(AppColorKey.chipBackground))
        .enabled(playerStore.libraryReady)
        .onClick(() => playerStore.toggleQueue(this.song))
    }
    .width('100%')
    .padding({ left: SongRowPadding.left, right: SongRowPadding.right, top: SongRowPadding.vertical, bottom: SongRowPadding.vertical })
    .backgroundColor($r(AppColorKey.cardBackground))
    .borderRadius(Radius.md)
    .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
    .onClick(() => playerStore.playSong(this.song))
  }
}

/**
 * 标签 chip(热搜词、搜索历史)。
 */
@Builder
export function Chip(text: string, onClick: () => void) {
  Text(text)
    .fontSize(13)
    .fontColor($r(AppColorKey.textSecondary))
    .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
    .backgroundColor($r(AppColorKey.chipBackground))
    .borderRadius(Radius.lg)
    .margin({ right: Space.sm, bottom: Space.sm })
    .onClick(() => onClick())
}
