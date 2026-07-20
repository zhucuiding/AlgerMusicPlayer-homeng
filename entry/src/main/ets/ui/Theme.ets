/**
 * 公共样式常量
 *
 * 注意:ArkTS 中不在模块顶层缓存 $r('app.color.xxx') 返回的 Resource,
 * 颜色仍由各组件就地使用 $r('app.color.<name>') 引用,以保证主题切换生效。
 * 此处只集中管理纯数值(间距、圆角、边框)与颜色 token 的字符串 key。
 */

/** 颜色资源 token 字符串,统一命名避免拼写漂移 */
export class AppColorKey {
  static readonly pageBackground: string = 'app.color.page_background';
  static readonly cardBackground: string = 'app.color.card_background';
  static readonly textPrimary: string = 'app.color.text_primary';
  static readonly textSecondary: string = 'app.color.text_secondary';
  static readonly textHint: string = 'app.color.text_hint';
  static readonly accent: string = 'app.color.accent';
  static readonly chipBackground: string = 'app.color.chip_background';
  static readonly borderColor: string = 'app.color.border_color';
  static readonly errorColor: string = 'app.color.error_color';
  static readonly tabBarBackground: string = 'app.color.tab_bar_background';
}

/** 间距常量(单位 vp) */
export class Space {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly xxl: number = 24;
}

/** 圆角常量(单位 vp) */
export class Radius {
  static readonly sm: number = 10;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly pill: number = 20;
}

/** 卡片边框 */
export class CardBorder {
  static readonly width: number = 0.5;
}

/** 列表行内边距 */
export class SongRowPadding {
  static readonly left: number = 16;
  static readonly right: number = 12;
  static readonly vertical: number = 10;
}
