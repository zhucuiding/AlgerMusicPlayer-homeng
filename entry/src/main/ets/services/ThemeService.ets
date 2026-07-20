import { ConfigurationConstant, common } from '@kit.AbilityKit';

export type ThemeMode = 'auto' | 'light' | 'dark';

export class ThemeService {
  private mode: ThemeMode = 'auto';

  setMode(mode: ThemeMode): void {
    this.mode = mode;
  }

  getMode(): ThemeMode {
    return this.mode;
  }

  apply(context: common.UIAbilityContext): void {
    const appContext = context.getApplicationContext();
    switch (this.mode) {
      case 'light':
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
        break;
      case 'dark':
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
        break;
      default:
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    }
  }
}

export const themeService = new ThemeService();
