# 第二类 · 项目记录 · AlgerMusicPlayer

> 单个项目的目标、决策、进展、踩坑。每条按时间倒序累积，新内容放最上面。

## 写入规则（AI 必读）

1. **写什么**：项目目标与范围、关键技术决策、阶段性进展、遇到的坑与解法、待办与下一步。
2. **不写什么**：单次提交号、临时构建日志、敏感凭据路径原文、一次性的 console 输出。
3. **格式**：每条以 `### YYYY-MM-DD · 简述` 为标题，下面分 `背景 / 决策 / 结果 / 待办` 四段；没有的段写"无"。
4. **更新方式**：新进展追加到 `## 进展` 顶部；旧条目只修正事实错误，不删除历史。踩坑写入 `## 踩坑` 并反向链接到对应的进展条目。
5. **确认机制**：每次推进项目后，AI 主动问"要不要把本次进展沉淀到 Projects？"，用户确认后由 AI 写入。
6. **与 SOP 的关系**：当某次任务抽象出可复用流程时，从本文件链接到 `SOP/analyze-user-feedback.md` 对应条目。

## 项目快照

- **项目名**：AlgerMusicPlayer（homeng 分支/副本）
- **类型**：HarmonyOS 原生应用（ArkTS）
- **路径**：`D:\data\project\AlgerMusicPlayer-homeng`
- **包名 / Vendor**：`com.zhucuiding.algermusicplayer` / `AlgerMusicPlayer`
- **版本**：1.0.0（versionCode 1000000）
- **目标 SDK**：HarmonyOS 6.1.0(23) / API 23
- **签名配置**：`C:\Users\GhostCloud\.ohos\config\default_AlgerMusicPlayer-homeng_*.cer/.p7b/.p12`（敏感，仅记路径模式）
- **核心模块**：
  - `entry/src/main/ets/pages/Index.ets` — 主页面（搜索、播放、收藏、歌单、播放模式）
  - `entry/src/main/ets/services/MusicApi.ets` — 在线音乐 API（数据源 `music-api.gdstudio.xyz/api.php`，音源 netease/joox/tidal）
  - `entry/src/main/ets/services/AudioPlayerService.ets` — 播放服务
  - `entry/src/main/ets/services/LocalMusicLibrary.ets` — 本地库（收藏/歌单/播放模式持久化）
  - `entry/src/main/ets/model/MusicModels.ets` — 数据模型（Song / SearchSong 等）
- **构建产物**：`entry/build/default/outputs/default/entry-default-signed.hap`

## 进展

### 2026-07-20 · 建立项目记录基线

- **背景**：用户希望在 AI 文件夹建立可持久化的对话记忆体系，避免新会话失忆。
- **决策**：按三类组织——Memory（偏好）/ Projects（项目）/ SOP（流程）；本项目作为 Projects 的首条实例。
- **结果**：已读取 `app.json5`、`build-profile.json5`、`Index.ets`、`MusicApi.ets` 核对项目快照事实；包名、SDK 版本、音源、模块结构均已验证。
- **待办**：首次真实开发任务尚未开始，待用户下达具体需求后回填。

## 踩坑

（暂无）

## 待办与下一步

- 等待用户下达首个开发任务。
- 首次任务完成后，若流程可复用，抽象到 `SOP/analyze-user-feedback.md`。

---

## 变更记录

- 2026-07-20：建立本文件，填入项目快照与首条基线记录。
