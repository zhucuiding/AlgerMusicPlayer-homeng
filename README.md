# AlgerMusicPlayer HarmonyOS

这是 AlgerMusicPlayer 的 HarmonyOS Stage/ArkTS 原生验证工程。

## 当前范围

- 搜索歌曲
- 获取歌曲播放 URL
- 使用 HarmonyOS AVPlayer 前台播放

## 数据服务要求

当前验证版直接调用项目原有移动端解析链路使用的 GD 音乐台 HTTPS API，不要求电脑运行 `30488` 服务。搜索和播放 URL 请求均由 HAP 在手机上直接发出。

该接口属于第三方服务，存在可用性、版权、内容匹配和隐私边界；生产版本应迁移到可控且合规的 HTTPS 后端。

## 构建环境

- DevEco Studio 6.1.1.290
- HarmonyOS SDK 6.1.1 / API 24
- `compatibleSdkVersion`: HarmonyOS 6.1.0 / API 23
- Stage 模型，ArkTS，entry HAP

签名文件和凭据不进入 Git。

首次在新环境构建签名 HAP 时，需要通过 DevEco Studio 的 `Project Structure > Project > Signing Configs` 重新生成本机 Debug 签名。
