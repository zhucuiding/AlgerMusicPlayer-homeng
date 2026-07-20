import { common } from '@kit.AbilityKit';
import { Song, songKey, Playlist, HistoryEntry } from '../model/MusicModels';
import { playerStore } from '../services/PlayerStore';
import { musicApi } from '../services/MusicApi';
import { themeService } from '../services/ThemeService';

import { HomeTab } from './HomeTab';
import { SearchTab } from './SearchTab';
import { SongCard } from '../ui/components/SongCard';
import { FullPlayer } from '../ui/components/FullPlayer';
import { AppColorKey, Space, Radius, CardBorder } from '../ui/Theme';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State showFullPlayer: boolean = false;
  @State showSpeedPicker: boolean = false;
  @State showNewPlaylistDialog: boolean = false;
  @State newPlaylistName: string = '';
  @State showSleepDialog: boolean = false;
  @State sleepMinutes: number = 30;
  @State showEqualizer: boolean = false;
  @State storeVersion: number = 0;
  @State showPlaylistDetail: boolean = false;
  @State playlistDetailName: string = '';
  @State playlistDetailSongs: Song[] = [];
  @State playlistDetailLoading: boolean = false;
  @State playlistDetailId: string = '';
  @State toastMessage: string = '';
  @State pendingSearchKeyword: string = '';
  @State pendingSearchVersion: number = 0;

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    playerStore.subscribe(() => {
      this.storeVersion++;
    });
    playerStore.initialize(context).then(() => {
      // 首页数据由 HomeTab 自加载,此处无需额外触发
    });
  }

  private showToast(msg: string): void {
    this.toastMessage = msg;
    setTimeout(() => {
      if (this.toastMessage === msg) {
        this.toastMessage = '';
      }
    }, 2000);
  }

  private async openPlaylist(id: string, name: string): Promise<void> {
    this.showPlaylistDetail = true;
    this.playlistDetailId = id;
    this.playlistDetailName = name;
    this.playlistDetailSongs = [];
    this.playlistDetailLoading = true;
    try {
      const detail = await musicApi.getPlaylistDetail(id, 'netease');
      if (detail && detail.tracks.length > 0) {
        this.playlistDetailSongs = detail.tracks;
        this.showToast(`加载了 ${detail.tracks.length} 首歌`);
      } else {
        this.showToast('歌单为空或加载失败');
      }
    } catch (error) {
      this.showToast('加载歌单失败');
    } finally {
      this.playlistDetailLoading = false;
    }
  }

  private artistNames(song: Song): string {
    return song.artists.map((artist) => artist.name).join(' / ');
  }

  @Builder
  PlaylistTab() {
    Column({ space: Space.md }) {
      Row() {
        Text('歌单').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary)).layoutWeight(1)
        Button('新建')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor($r(AppColorKey.accent))
          .height(32)
          .onClick(() => this.showNewPlaylistDialog = true)
      }
      .width('100%')

      if (playerStore.customPlaylists.length === 0) {
        Column({ space: Space.sm }) {
          Text('还没有自建歌单').fontSize(14).fontColor($r(AppColorKey.textHint))
          Text('点击右上角"新建"创建第一个歌单').fontSize(12).fontColor($r(AppColorKey.textHint))
        }
        .width('100%')
        .padding(40)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: Space.sm }) {
          ForEach(playerStore.customPlaylists, (pl: Playlist) => {
            ListItem() {
              Row({ space: Space.lg }) {
                Column({ space: Space.xs }) {
                  Text(pl.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r(AppColorKey.textPrimary)).maxLines(1)
                  Text(`${pl.songs.length} 首`).fontSize(12).fontColor($r(AppColorKey.textHint))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Button('删除').fontSize(11).fontColor($r(AppColorKey.errorColor)).backgroundColor($r(AppColorKey.chipBackground)).height(28)
                  .onClick(() => {
                    playerStore.deletePlaylist(pl.id);
                    if (this.playlistDetailId === pl.id) {
                      this.showPlaylistDetail = false;
                    }
                  })
              }
              .width('100%')
              .padding(Space.md)
              .backgroundColor($r(AppColorKey.cardBackground))
              .borderRadius(Radius.md)
              .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
            }
          }, (pl: Playlist) => pl.id)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.md })
  }

  @Builder
  MineTab() {
    Column({ space: Space.md }) {
      Text('我的').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary)).width('100%')

      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
          Text(`${playerStore.favorites.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.accent))
          Text('喜欢').fontSize(11).fontColor($r(AppColorKey.textHint))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 2 }) {
          Text(`${playerStore.collection.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.accent))
          Text('收藏').fontSize(11).fontColor($r(AppColorKey.textHint))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 2 }) {
          Text(`${playerStore.queue.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.accent))
          Text('播放列表').fontSize(11).fontColor($r(AppColorKey.textHint))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 2 }) {
          Text(`${playerStore.history.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.accent))
          Text('历史').fontSize(11).fontColor($r(AppColorKey.textHint))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding(Space.md)
      .backgroundColor($r(AppColorKey.cardBackground))
      .borderRadius(Radius.md)
      .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })

      if (playerStore.history.length > 0) {
        Text('最近播放').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r(AppColorKey.textPrimary)).width('100%')
        List({ space: Space.sm }) {
          ForEach(playerStore.history.slice(0, 20), (entry: HistoryEntry) => {
            ListItem() {
              SongCard({ song: entry.song })
            }
          }, (entry: HistoryEntry) => `${entry.song.source}:${entry.song.id}:${entry.playedAt}`)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.md })
  }

  @Builder
  SettingsTab() {
    Column({ space: Space.md }) {
      Text('设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary)).width('100%')

      // 播放模式
      this.SettingsRow('播放模式', this.playModeLabel(), () => {});
      // 音质、倍速、定时、均衡器、主题等以简化方式呈现于下方说明
      // (为控制本文件体积,部分设置项沿用内联实现)
      this.InlineSelectRow('音质', ['标准 (128k)', '较高 (320k)', '无损'],
        playerStore.quality === 'lossless' ? '无损' : playerStore.quality === 'high' ? '较高 (320k)' : '标准 (128k)',
        (index: number) => playerStore.setQuality(['standard', 'high', 'lossless'][index]));

      this.InlineSelectRow('倍速播放', ['0.75x', '1.0x', '1.25x', '1.5x', '2.0x'],
        `${playerStore.playbackSpeed}x`,
        (index: number) => playerStore.setPlaybackSpeed([0.75, 1.0, 1.25, 1.5, 2.0][index]));

      // 定时关闭
      Row() {
        Text('定时关闭').fontSize(14).fontColor($r(AppColorKey.textPrimary)).layoutWeight(1)
        if (playerStore.sleepActive) {
          Text(`${Math.ceil(playerStore.sleepRemaining / 60000)}分钟`)
            .fontSize(13).fontColor($r(AppColorKey.accent))
          Button('取消').fontSize(11).fontColor(Color.White).backgroundColor($r(AppColorKey.errorColor)).height(28).margin({ left: Space.sm })
            .onClick(() => playerStore.cancelSleepTimer())
        } else {
          Button('设置').fontSize(11).fontColor(Color.White).backgroundColor($r(AppColorKey.textPrimary)).height(28)
            .onClick(() => this.showSleepDialog = true)
        }
      }
      .width('100%')
      .padding(Space.md)
      .backgroundColor($r(AppColorKey.cardBackground))
      .borderRadius(Radius.md)
      .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })

      // 均衡器(开发中,bug #2:禁用以避免假实现误导)
      Row() {
        Text('均衡器').fontSize(14).fontColor($r(AppColorKey.textPrimary)).layoutWeight(1)
        Text('开发中').fontSize(11).fontColor($r(AppColorKey.textHint))
      }
      .width('100%')
      .padding(Space.md)
      .backgroundColor($r(AppColorKey.cardBackground))
      .borderRadius(Radius.md)
      .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })

      // 主题
      this.InlineSelectRow('主题', ['跟随系统', '浅色', '深色'],
        this.themeLabel(),
        (index: number) => {
          const modes: string[] = ['auto', 'light', 'dark'];
          const mode: string = modes[index];
          themeService.setMode(mode as 'auto' | 'light' | 'dark');
          const context = getContext(this) as common.UIAbilityContext;
          themeService.apply(context);
          playerStore.saveSettings();
        });

      Button('清空播放历史')
        .width('100%')
        .height(40)
        .fontSize(13)
        .fontColor($r(AppColorKey.errorColor))
        .backgroundColor($r(AppColorKey.cardBackground))
        .borderRadius(Radius.md)
        .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
        .onClick(() => playerStore.clearHistory())

      Button('清空搜索历史')
        .width('100%')
        .height(40)
        .fontSize(13)
        .fontColor($r(AppColorKey.errorColor))
        .backgroundColor($r(AppColorKey.cardBackground))
        .borderRadius(Radius.md)
        .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
        .onClick(() => playerStore.clearSearchHistory())

      Text('AlgerMusicPlayer HarmonyOS v1.1.0').fontSize(11).fontColor($r(AppColorKey.textHint)).width('100%').textAlign(TextAlign.Center).margin({ top: Space.xl })
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.md })
  }

  private playModeLabel(): string {
    return playerStore.playMode === 'single' ? '单曲循环' : playerStore.shuffle ? '随机播放' : '顺序播放';
  }

  private themeLabel(): string {
    return themeService.getMode() === 'light' ? '浅色' : themeService.getMode() === 'dark' ? '深色' : '跟随系统';
  }

  @Builder
  SettingsRow(label: string, value: string, _onClick: () => void) {
    Row() {
      Text(label).fontSize(14).fontColor($r(AppColorKey.textPrimary)).layoutWeight(1)
      Select([
        { value: '顺序播放' },
        { value: '单曲循环' },
        { value: '随机播放' }
      ])
        .value(value)
        .onSelect((index: number) => {
          playerStore.setPlayMode(['sequence', 'single', 'shuffle'][index]);
        })
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor($r(AppColorKey.cardBackground))
    .borderRadius(Radius.md)
    .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
  }

  @Builder
  InlineSelectRow(label: string, options: string[], value: string, onSelect: (index: number) => void) {
    Row() {
      Text(label).fontSize(14).fontColor($r(AppColorKey.textPrimary)).layoutWeight(1)
      Select(options.map((o: string): SelectOption => ({ value: o })))
        .value(value)
        .onSelect((index: number) => onSelect(index))
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor($r(AppColorKey.cardBackground))
    .borderRadius(Radius.md)
    .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
  }

  @Builder
  MiniPlayer() {
    if (playerStore.currentSong && this.storeVersion >= 0) {
      Row({ space: Space.md }) {
        Text('🎵').fontSize(24)
        Column({ space: 2 }) {
          Text(playerStore.currentSong!.name)
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r(AppColorKey.textPrimary)).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.artistNames(playerStore.currentSong!))
            .fontSize(11).fontColor($r(AppColorKey.textHint)).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(playerStore.playerState === 'playing' ? '暂停' : '播放')
          .fontSize(12).fontColor(Color.White).backgroundColor($r(AppColorKey.accent)).height(32)
          .onClick(() => playerStore.togglePlay())
        Button('下一首').fontSize(11).fontColor($r(AppColorKey.textPrimary)).backgroundColor($r(AppColorKey.chipBackground)).height(32)
          .onClick(() => playerStore.playNext())
      }
      .width('100%')
      .padding({ left: Space.md, right: Space.md, top: Space.md, bottom: Space.md })
      .backgroundColor($r(AppColorKey.cardBackground))
      .borderRadius(Radius.lg)
      .border({ width: CardBorder.width, color: $r(AppColorKey.borderColor) })
      .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: -1 })
      .onClick(() => this.showFullPlayer = true)
    }
  }

  @Builder
  NewPlaylistDialog() {
    Column({ space: Space.lg }) {
      Text('新建歌单').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary))
      TextInput({ placeholder: '歌单名称' })
        .height(44)
        .backgroundColor($r(AppColorKey.chipBackground))
        .borderRadius(Radius.sm)
        .onChange((value: string) => this.newPlaylistName = value)
      Row({ space: Space.md }) {
        Button('取消').layoutWeight(1).height(40)
          .onClick(() => {
            this.showNewPlaylistDialog = false;
            this.newPlaylistName = '';
          })
        Button('创建').layoutWeight(1).height(40)
          .fontColor(Color.White).backgroundColor($r(AppColorKey.accent))
          .onClick(async () => {
            if (this.newPlaylistName.trim()) {
              await playerStore.createPlaylist(this.newPlaylistName.trim());
              this.showNewPlaylistDialog = false;
              this.newPlaylistName = '';
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.xl)
  }

  @Builder
  SleepDialog() {
    Column({ space: Space.lg }) {
      Text('定时关闭').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary))
      Row({ space: Space.sm }) {
        this.SleepMinuteButton(15);
        this.SleepMinuteButton(30);
        this.SleepMinuteButton(45);
        this.SleepMinuteButton(60);
      }
      .width('100%')
      Button('开始定时')
        .width('100%').height(40)
        .fontColor(Color.White).backgroundColor($r(AppColorKey.accent))
        .onClick(() => {
          playerStore.startSleepTimer(this.sleepMinutes * 60 * 1000);
          this.showSleepDialog = false;
        })
      Button('取消')
        .width('100%').height(40)
        .fontColor($r(AppColorKey.textSecondary)).backgroundColor($r(AppColorKey.chipBackground))
        .onClick(() => this.showSleepDialog = false)
    }
    .width('100%')
    .padding(Space.xl)
  }

  @Builder
  SleepMinuteButton(min: number) {
    Button(`${min}分`).layoutWeight(1).height(36).fontSize(12)
      .backgroundColor(this.sleepMinutes === min ? $r(AppColorKey.accent) : $r(AppColorKey.chipBackground))
      .fontColor(this.sleepMinutes === min ? Color.White : $r(AppColorKey.textPrimary))
      .onClick(() => this.sleepMinutes = min)
  }

  @Builder
  PlaylistDetailPanel() {
    Column({ space: Space.md }) {
      Row() {
        Button('关闭').fontSize(13).fontColor($r(AppColorKey.textSecondary)).backgroundColor('transparent')
          .onClick(() => this.showPlaylistDetail = false)
        Blank().layoutWeight(1)
        Text(this.playlistDetailName).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary))
        Blank().layoutWeight(1)
        Text('').width(44)
      }
      .width('100%')

      if (this.playlistDetailLoading) {
        Text('加载中…').fontSize(14).fontColor($r(AppColorKey.textHint)).width('100%').textAlign(TextAlign.Center).padding(30)
      } else if (this.playlistDetailSongs.length > 0) {
        Row() {
          Button('全部播放')
            .fontSize(13).fontColor(Color.White).backgroundColor($r(AppColorKey.accent)).height(36)
            .onClick(() => {
              const songs = this.playlistDetailSongs;
              if (songs.length > 0) {
                playerStore.playSong(songs[0], songs);
              }
            })
          Blank().layoutWeight(1)
          Text(`${this.playlistDetailSongs.length} 首`).fontSize(12).fontColor($r(AppColorKey.textHint))
        }
        .width('100%')

        List({ space: Space.sm }) {
          ForEach(this.playlistDetailSongs, (song: Song) => {
            ListItem() {
              SongCard({ song: song })
            }
          }, (song: Song) => songKey(song))
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Text('歌单为空').fontSize(14).fontColor($r(AppColorKey.textHint)).width('100%').textAlign(TextAlign.Center).padding(30)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.xl })
  }

  build() {
    Stack() {
      Column() {
        Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
          TabContent() {
            HomeTab({
              onHotSearchTap: (keyword: string) => {
                this.currentIndex = 1;
                this.pendingSearchKeyword = keyword;
                this.pendingSearchVersion++;
              },
              onOpenPlaylist: (id: string, name: string) => {
                this.openPlaylist(id, name);
              }
            })
          }.tabBar('首页')

          TabContent() {
            SearchTab({
              pendingKeyword: this.pendingSearchKeyword,
              pendingVersion: this.pendingSearchVersion
            })
          }.tabBar('搜索')

          TabContent() {
            this.PlaylistTab()
          }.tabBar('歌单')

          TabContent() {
            this.MineTab()
          }.tabBar('我的')

          TabContent() {
            this.SettingsTab()
          }.tabBar('设置')
        }
        .width('100%')
        .layoutWeight(1)
        .barBackgroundColor($r(AppColorKey.tabBarBackground))

        // 迷你播放器
        Column() {
          this.MiniPlayer()
        }
        .width('100%')
        .padding({ left: Space.sm, right: Space.sm, bottom: Space.xs })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r(AppColorKey.pageBackground))
      .bindSheet(this.showNewPlaylistDialog, this.NewPlaylistDialog(), { height: 200, dragBar: true })
      .bindSheet(this.showSleepDialog, this.SleepDialog(), { height: 300, dragBar: true })
      .bindSheet(this.showEqualizer, this.EqualizerPanel(), { height: 400, dragBar: true })
      .bindSheet(this.showPlaylistDetail, this.PlaylistDetailPanel(), { height: SheetSize.LARGE, dragBar: true })
      .bindSheet(this.showSpeedPicker, this.SpeedPickerBuilder(), { height: 260, dragBar: true })

      if (this.toastMessage) {
        Text(this.toastMessage)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#CC000000')
          .padding({ left: Space.lg, right: Space.lg, top: Space.md, bottom: Space.md })
          .borderRadius(Radius.pill)
          .position({ x: '50%', y: '80%' })
          .translate({ x: '-50%' })
          .zIndex(9999)
      }

      if (this.showFullPlayer) {
        FullPlayer({ show: $showFullPlayer, showSpeedPicker: $showSpeedPicker })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SpeedPickerBuilder() {
    Column({ space: Space.lg }) {
      Text('倍速播放').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary)).width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach([0.75, 1.0, 1.25, 1.5, 2.0], (speed: number) => {
          Button(`${speed}x`)
            .fontSize(13)
            .fontColor(playerStore.playbackSpeed === speed ? Color.White : $r(AppColorKey.textSecondary))
            .backgroundColor(playerStore.playbackSpeed === speed ? $r(AppColorKey.accent) : $r(AppColorKey.chipBackground))
            .height(40)
            .padding({ left: Space.lg, right: Space.lg })
            .borderRadius(Radius.lg)
            .margin({ right: Space.sm, bottom: Space.sm })
            .onClick(() => {
              playerStore.setPlaybackSpeed(speed);
              this.showSpeedPicker = false;
            })
        }, (speed: number) => `${speed}`)
      }
      .width('100%')
      Button('关闭')
        .width('100%').height(40)
        .fontColor($r(AppColorKey.textSecondary)).backgroundColor($r(AppColorKey.chipBackground))
        .onClick(() => this.showSpeedPicker = false)
    }
    .width('100%')
    .padding(Space.xl)
  }

  @Builder
  EqualizerPanel() {
    Column({ space: Space.lg }) {
      Text('均衡器').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r(AppColorKey.textPrimary))
      Text('该功能正在开发中,暂不可用。').fontSize(13).fontColor($r(AppColorKey.textHint)).width('100%')
      Button('关闭')
        .width('100%').height(40)
        .fontColor($r(AppColorKey.textSecondary)).backgroundColor($r(AppColorKey.chipBackground))
        .onClick(() => this.showEqualizer = false)
    }
    .width('100%')
    .padding(Space.xl)
  }
}
