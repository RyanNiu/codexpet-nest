import type { WidgetSlot } from '@codexpet/core';

export type BuiltInWidgetId = 'usage' | 'clock' | 'countdown' | 'pomodoro';

export interface ResolvedWidgetSlot extends WidgetSlot {
  id: string;
}
