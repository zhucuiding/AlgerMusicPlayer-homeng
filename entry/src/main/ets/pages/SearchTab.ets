import { Song } from '../model/MusicModels';
import { playerStore } from '../services/PlayerStore';
import { musicApi } from '../services/MusicApi';
import { SongCard } from '../ui/components/SongCard';
import { AppColorKey, Space, Radius } from '../ui/Theme';

/**
 * 搜索 Tab:输入框 + 搜索结果 / 搜索历史。
 *
 * keyword / searchResults / searchLoading / searchMessage 由本组件持有,
 * 切到搜索 Tab 时父组件可通过 onKeywordChange 注入外部关键词(如热搜点击)。
 */
@Component
export struct SearchTab {
  @State keyword: string = '';
  @State searchResults: Song[] = [];
  @State searchLoading: boolean = false;
  @State searchMessage: string = '';
  @State searchHistoryVersion: number = 0;
  @Prop @Watch('onPendingChange') pendingKeyword: string = '';
  @Prop @Watch('onPendingChange') pendingVersion: number = 0;
  private searchGeneration: number = 0;
  private storeObserver: (() => void) | null = null;
  private lastPendingVersion: number = 0;

  aboutToAppear(): void {
    this.storeObserver = playerStore.subscribe(() => {
      this.searchHistoryVersion++;
    });
  }

  aboutToDisappear(): void {
    this.storeObserver?.();
  }

  /** 父组件注入外部关键词(如首页热搜点击)时触发搜索 */
  private onPendingChange(): void {
    if (this.pendingVersion !== this.lastPendingVersion && this.pendingKeyword) {
      this.lastPendingVersion = this.pendingVersion;
      this.keyword = this.pendingKeyword;
      this.search();
    }
  }

  async search(): Promise<void> {
    const generation = ++this.searchGeneration;
    const kw = this.keyword.trim();
    if (!kw) {
      this.searchMessage = '请输入歌曲或歌手名称';
      return;
    }
    await playerStore.addSearchHistory(kw);
    this.searchLoading = true;
    this.searchMessage = '正在搜索…';
    try {
      const songs = await musicApi.search(kw);
      if (generation !== this.searchGeneration) {
        return;
      }
      this.searchResults = songs;
      this.searchMessage = songs.length > 0 ? `找到 ${songs.length} 首歌曲` : '没有找到歌曲';
    } catch (error) {
      if (generation !== this.searchGeneration) {
        return;
      }
      this.searchResults = [];
      this.searchMessage = `搜索失败：${error instanceof Error ? error.message : error}`;
    } finally {
      if (generation === this.searchGeneration) {
        this.searchLoading = false;
      }
    }
  }

  /** 供父组件注入外部关键词并触发搜索(如首页热搜点击) — 已改为 @Prop @Watch 驱动 */

  build() {
    Column({ space: Space.md }) {
      Text('搜索').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary)).width('100%')

      Row({ space: Space.sm }) {
        TextInput({ text: this.keyword, placeholder: '歌曲或歌手' })
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r(AppColorKey.cardBackground))
          .borderRadius(Radius.sm)
          .onChange((value: string) => this.keyword = value)
          .onSubmit(() => this.search())
        Button(this.searchLoading ? '搜索中' : '搜索')
          .height(44)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r(AppColorKey.accent))
          .enabled(!this.searchLoading)
          .onClick(() => this.search())
      }
      .width('100%')

      if (this.searchMessage) {
        Text(this.searchMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(this.searchMessage.includes('失败') ? $r(AppColorKey.errorColor) : $r(AppColorKey.textHint))
      }

      if (this.searchResults.length > 0) {
        List({ space: Space.sm }) {
          ForEach(this.searchResults, (song: Song) => {
            ListItem() {
              SongCard({ song: song })
            }
          }, (song: Song) => `${song.source}:${song.id}`)
        }
        .width('100%')
        .layoutWeight(1)
      } else if (playerStore.searchHistory.length > 0) {
        Text('搜索历史').fontSize(13).fontColor($r(AppColorKey.textSecondary)).width('100%').margin({ top: Space.xs })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(playerStore.searchHistory, (kw: string) => {
            Text(kw)
              .fontSize(13)
              .fontColor($r(AppColorKey.textSecondary))
              .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
              .backgroundColor($r(AppColorKey.chipBackground))
              .borderRadius(Radius.lg)
              .margin({ right: Space.sm, bottom: Space.sm })
              .onClick(() => {
                this.keyword = kw;
                this.search();
              })
          }, (kw: string) => kw)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.md })
  }
}
