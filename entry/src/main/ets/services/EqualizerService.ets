export interface EqualizerBand {
  freq: number;
  gain: number;
}

export class EqualizerService {
  private enabled: boolean = false;
  private preset: string = 'flat';
  private gains: number[] = [0, 0, 0, 0, 0];
  private presetNames: string[] = ['flat', 'bass', 'treble', 'vocal', 'rock', 'pop', 'classical'];
  private presetGains: Map<string, number[]> = new Map<string, number[]>();

  constructor() {
    const flat: number[] = [0, 0, 0, 0, 0];
    const bass: number[] = [6, 4, 2, 0, 0];
    const treble: number[] = [0, 0, 2, 4, 6];
    const vocal: number[] = [0, 2, 4, 2, 0];
    const rock: number[] = [4, 2, -1, 2, 4];
    const pop: number[] = [-1, 2, 4, 2, -1];
    const classical: number[] = [3, 2, 0, 2, 3];
    this.presetGains.set('flat', flat);
    this.presetGains.set('bass', bass);
    this.presetGains.set('treble', treble);
    this.presetGains.set('vocal', vocal);
    this.presetGains.set('rock', rock);
    this.presetGains.set('pop', pop);
    this.presetGains.set('classical', classical);
  }

  getBands(): EqualizerBand[] {
    const freqs: number[] = [60, 230, 910, 3600, 14000];
    const bands: EqualizerBand[] = [];
    for (let i = 0; i < freqs.length; i++) {
      const freq: number = freqs[i];
      const gain: number = this.gains[i] ?? 0;
      const band: EqualizerBand = { freq, gain };
      bands.push(band);
    }
    return bands;
  }

  getPresets(): string[] {
    const result: string[] = [];
    for (const name of this.presetNames) {
      result.push(name);
    }
    return result;
  }

  applyPreset(name: string): void {
    const gains: number[] | undefined = this.presetGains.get(name);
    if (!gains) {
      return;
    }
    this.preset = name;
    const copy: number[] = [];
    for (const g of gains) {
      copy.push(g);
    }
    this.gains = copy;
  }

  setBand(index: number, gain: number): void {
    if (index < 0 || index >= this.gains.length) {
      return;
    }
    this.gains[index] = gain;
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  getCurrentPreset(): string {
    return this.preset;
  }
}

export const equalizer = new EqualizerService();
