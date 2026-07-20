import { common } from '@kit.AbilityKit';
import { ToplistEntry, HotSearchEntry, DailyRecommendEntry } from '../model/MusicModels';
import { musicApi } from '../services/MusicApi';
import { SongCard } from '../ui/components/SongCard';
import { AppColorKey, Space, Radius, CardBorder } from '../ui/Theme';

/**
 * 首页 Tab:发现 / 每日推荐 / 热搜 / 榜单。
 *
 * 自包含:数据由本组件 loadHomeData() 加载,任一接口失败不阻塞其余区块。
 */
@Component
export struct HomeTab {
  @State toplists: ToplistEntry[] = [];
  @State hotSearch: HotSearchEntry[] = [];
  @State dailyRecommend: DailyRecommendEntry[] = [];
  @State homeLoading: boolean = false;
  @State toastMessage: string = '';

  aboutToAppear(): void {
    this.loadHomeData();
  }

  private showToast(msg: string): void {
    this.toastMessage = msg;
    setTimeout(() => {
      if (this.toastMessage === msg) {
        this.toastMessage = '';
      }
    }, 2000);
  }

  async loadHomeData(): Promise<void> {
    this.homeLoading = true;
    // 各区块独立加载,任一失败不阻塞其余
    const tasks: Promise<void>[] = [
      this.loadToplists(),
      this.loadHotSearch(),
      this.loadDailyRecommend()
    ];
    await Promise.all(tasks);
    this.homeLoading = false;
  }

  private async loadToplists(): Promise<void> {
    try {
      this.toplists = await musicApi.getToplists('netease');
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      console.error('loadToplists: ' + msg);
    }
  }

  private async loadHotSearch(): Promise<void> {
    try {
      this.hotSearch = await musicApi.getHotSearch('netease');
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      console.error('loadHotSearch: ' + msg);
    }
  }

  private async loadDailyRecommend(): Promise<void> {
    try {
      this.dailyRecommend = await musicApi.getDailyRecommend('netease');
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      console.error('loadDailyRecommend: ' + msg);
    }
  }

  build() {
    Scroll() {
      Column({ space: Space.md }) {
        Text('发现').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary))
          .width('100%')

        if (this.dailyRecommend.length > 0) {
          Text('每日推荐').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r(AppColorKey.textPrimary)).width('100%')
          Text('基于热门歌曲的每日推荐').fontSize(11).fontColor($r(AppColorKey.textHint)).width('100%').margin({ bottom: Space.xs })
          List({ space: Space.sm }) {
            ForEach(this.dailyRecommend.slice(0, 6), (entry: DailyRecommendEntry) => {
              ListItem() {
                SongCard({ song: entry.song })
              }
            }, (entry: DailyRecommendEntry) => `${entry.song.source}:${entry.song.id}`)
          }
          .width('100%')
        }

        if (this.hotSearch.length > 0) {
          Text('热搜').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r(AppColorKey.textPrimary)).width('100%').margin({ top: Space.sm })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.hotSearch.slice(0, 10), (entry: HotSearchEntry) => {
              Text(entry.keyword)
                .fontSize(13)
                .fontColor($r(AppColorKey.textSecondary))
                .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
                .backgroundColor($r(AppColorKey.chipBackground))
                .borderRadius(Radius.lg)
                .margin({ right: Space.sm, bottom: Space.sm })
                .onClick(() => {
                  this.onHotSearchTap(entry.keyword);
                })
            }, (entry: HotSearchEntry) => entry.keyword)
          }
          .width('100%')
        }

        if (this.toplists.length > 0) {
          Text('榜单').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r(AppColorKey.textPrimary)).width('100%').margin({ top: Space.sm })
          List({ space: Space.sm }) {
            ForEach(this.toplists.slice(0, 5), (entry: ToplistEntry) => {
              ListItem() {
                Row({ space: Space.lg }) {
                  Text(entry.name)
                    .fontSize(14)
                    .fontColor($r(AppColorKey.textPrimary))
                    .layoutWeight(1)
                  Text(entry.updateFrequency ?? '')
                    .fontSize(11)
                    .fontColor($r(AppColorKey.textHint))
                  Text('▶')
                    .fontSize(12)
                    .fontColor($r(AppColorKey.accent))
                }
                .width('100%')
                .padding(Space.md)
                .backgroundColor($r(AppColorKey.cardBackground))
                .borderRadius(Radius.md)
                .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
                .onClick(() => this.onOpenPlaylist(entry.id, entry.name))
              }
            }, (entry: ToplistEntry) => entry.id)
          }
          .width('100%')
        }

        if (this.homeLoading) {
          Text('加载中…').fontSize(13).fontColor($r(AppColorKey.textHint)).width('100%').textAlign(TextAlign.Center).padding(Space.xl)
        } else if (this.dailyRecommend.length === 0 && this.hotSearch.length === 0 && this.toplists.length === 0) {
          Column({ space: Space.md }) {
            Text('数据加载失败或为空').fontSize(13).fontColor($r(AppColorKey.textHint)).width('100%').textAlign(TextAlign.Center)
            Button('重试')
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor($r(AppColorKey.accent))
              .height(36)
              .padding({ left: Space.xl, right: Space.xl })
              .onClick(() => this.loadHomeData())
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding(40)
        }
      }
      .width('100%')
      .padding({ left: Space.lg, right: Space.lg, top: Space.md })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  // 占位:由父组件(Index)注入实际回调,以切 Tab + 打开歌单详情
  onHotSearchTap: (keyword: string) => void = () => {};
  onOpenPlaylist: (id: string, name: string) => void = () => {};
}
