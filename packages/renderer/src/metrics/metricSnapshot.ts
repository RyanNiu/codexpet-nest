import type { MetricSnapshot, MockUsageMetrics } from './types';

export function createMetricSnapshot(
  now = new Date(),
  usage: MockUsageMetrics = {},
): MetricSnapshot {
  const primaryRemainingPercent = usage.primaryRemainingPercent ?? 68;
  const source = usage.source ?? 'mocked';

  return {
    'system.time.hhmm': { kind: 'text', value: formatTime(now) },
    'system.date.short': { kind: 'text', value: formatDate(now) },
    'system.time.day_period': {
      kind: 'enumeration',
      value: now.getHours() >= 6 && now.getHours() < 18 ? 'day' : 'night',
    },
    'usage.primary.remaining_percent':
      source === 'unavailable'
        ? { kind: 'unavailable', reason: 'usage metrics unavailable' }
        : { kind: 'percent', value: primaryRemainingPercent },
    'usage.primary.remaining_ratio':
      source === 'unavailable'
        ? { kind: 'unavailable', reason: 'usage metrics unavailable' }
        : { kind: 'ratio', value: primaryRemainingPercent / 100 },
    'usage.source':
      source === 'unavailable'
        ? { kind: 'unavailable', reason: 'usage metrics unavailable' }
        : { kind: 'enumeration', value: source },
  };
}

function formatTime(date: Date): string {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function formatDate(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}
