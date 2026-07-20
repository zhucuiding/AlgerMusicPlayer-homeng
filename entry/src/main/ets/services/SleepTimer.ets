export type SleepTimerListener = (remaining: number, active: boolean) => void;
export type SleepTimerEndListener = () => void;

export class SleepTimerService {
  private timerId: number = -1;
  private endTime: number = 0;
  private remaining: number = 0;
  private listener?: SleepTimerListener;
  private endListener?: SleepTimerEndListener;

  setListener(listener: SleepTimerListener): void {
    this.listener = listener;
  }

  setEndListener(listener: SleepTimerEndListener): void {
    this.endListener = listener;
  }

  start(durationMs: number): void {
    this.cancel();
    this.remaining = durationMs;
    this.endTime = Date.now() + durationMs;
    this.timerId = setInterval(() => {
      const left = this.endTime - Date.now();
      this.remaining = Math.max(0, left);
      this.listener?.(this.remaining, true);
      if (left <= 0) {
        this.cancel();
        this.endListener?.();
      }
    }, 1000);
    this.listener?.(this.remaining, true);
  }

  cancel(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.remaining = 0;
    this.endTime = 0;
    this.listener?.(0, false);
  }

  isActive(): boolean {
    return this.timerId !== -1;
  }

  getRemaining(): number {
    return this.remaining;
  }
}

export const sleepTimer = new SleepTimerService();
