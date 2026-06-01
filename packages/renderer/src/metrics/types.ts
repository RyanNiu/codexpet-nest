export type MetricValue =
  | { kind: 'number'; value: number }
  | { kind: 'ratio'; value: number }
  | { kind: 'percent'; value: number }
  | { kind: 'text'; value: string }
  | { kind: 'boolean'; value: boolean }
  | { kind: 'enumeration'; value: string }
  | { kind: 'unavailable'; reason?: string };

export type MetricSnapshot = Record<string, MetricValue>;

export interface MockUsageMetrics {
  primaryRemainingPercent?: number;
  source?: 'mocked' | 'unavailable';
}
