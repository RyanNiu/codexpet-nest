import type { MetricBand, NestElement, NestLayoutManifest } from '@codexpet/core';
import type { MetricSnapshot, MetricValue } from '../metrics/types';
import type { NestRenderModel, RenderElement, RenderIssue, RenderModelInput } from './types';

const UNAVAILABLE: MetricValue = { kind: 'unavailable', reason: 'missing metric' };

export function buildNestRenderModel(input: RenderModelInput): NestRenderModel {
  const issues: RenderIssue[] = [];
  const derivedBands = computeMetricBands(input.theme, input.metrics);
  const metrics = applyMetricBands(input.metrics, derivedBands);

  return {
    canvas: input.theme.canvas,
    layers: input.theme.layers.map((layer) => ({
      id: layer.id,
      type: layer.type,
      src: layer.src,
      resolvedSrc: resolveAsset(layer.src, input.resolveAsset, issues),
      frame: layer.frame,
    })),
    widgetSlots: Object.entries(input.theme.widgetSlots ?? {}).map(([id, slot]) => ({
      id,
      ...slot,
    })),
    elements: (input.theme.elements ?? []).map((element) =>
      resolveElement(element, metrics, input.resolveAsset, issues),
    ),
    metricBands: derivedBands,
    issues,
  };
}

export function computeMetricBands(
  theme: NestLayoutManifest,
  metrics: MetricSnapshot,
): Record<string, string> {
  const bands: Record<string, string> = {};
  for (const [metric, thresholds] of Object.entries(theme.metricBands ?? {})) {
    const value = metrics[metric];
    if (!value || (value.kind !== 'percent' && value.kind !== 'number')) continue;
    const selected = selectBand(value.value, thresholds);
    if (selected) bands[toBandMetricId(metric)] = selected;
  }
  return bands;
}

function applyMetricBands(metrics: MetricSnapshot, bands: Record<string, string>): MetricSnapshot {
  const next = { ...metrics };
  for (const [metric, value] of Object.entries(bands)) {
    next[metric] = { kind: 'enumeration', value };
  }
  return next;
}

function resolveElement(
  element: NestElement,
  metrics: MetricSnapshot,
  resolveAssetFn: (path: string) => string | null,
  issues: RenderIssue[],
): RenderElement {
  if (element.type === 'staticImage') {
    return {
      id: element.id,
      type: 'staticImage',
      src: element.src,
      resolvedSrc: resolveAsset(element.src, resolveAssetFn, issues),
      frame: element.frame,
      style: element.style,
    };
  }

  if (element.type === 'variantImage') {
    const metricValue = getMetric(metrics, element.metric, issues);
    const selectedVariant = selectVariant(element, metricValue);
    return {
      id: element.id,
      type: 'variantImage',
      metric: element.metric,
      metricValue,
      selectedVariant,
      resolvedSrc: selectedVariant ? resolveAsset(selectedVariant, resolveAssetFn, issues) : null,
      frame: element.frame,
      style: element.style,
    };
  }

  if (element.type === 'metricText') {
    const metricValue = getMetric(metrics, element.metric, issues);
    return {
      id: element.id,
      type: 'metricText',
      metric: element.metric,
      metricValue,
      text: formatMetricText(metricValue, element.style),
      frame: element.frame,
      style: element.style,
    };
  }

  const metricValue = getMetric(metrics, element.metric, issues);
  return {
    id: element.id,
    type: 'metricGauge',
    metric: element.metric,
    metricValue,
    renderer: element.renderer,
    value: gaugeValue(metricValue),
    unavailable: metricValue.kind === 'unavailable',
    frame: element.frame,
    style: element.style,
  };
}

function resolveAsset(
  path: string,
  resolveAssetFn: (path: string) => string | null,
  issues: RenderIssue[],
): string | null {
  const resolved = resolveAssetFn(path);
  if (!resolved) {
    issues.push({ code: 'missing_asset', message: `Missing asset: ${path}`, path });
  }
  return resolved;
}

function getMetric(metrics: MetricSnapshot, metric: string, issues: RenderIssue[]): MetricValue {
  const value = metrics[metric] ?? UNAVAILABLE;
  if (value.kind === 'unavailable') {
    issues.push({ code: 'metric_unavailable', message: `Metric unavailable: ${metric}`, metric });
  }
  return value;
}

function selectVariant(
  element: Extract<NestElement, { type: 'variantImage' }>,
  value: MetricValue,
): string | null {
  if (value.kind === 'unavailable') return element.fallback ?? null;
  const key = String(value.value);
  return element.variants[key] ?? element.fallback ?? null;
}

function formatMetricText(value: MetricValue, style: Record<string, unknown> | undefined): string {
  if (value.kind === 'unavailable')
    return typeof style?.fallbackText === 'string' ? style.fallbackText : 'Unavailable';
  const prefix = typeof style?.prefix === 'string' ? style.prefix : '';
  const suffix = typeof style?.suffix === 'string' ? style.suffix : '';
  return `${prefix}${String(value.value)}${suffix}`;
}

function gaugeValue(value: MetricValue): number {
  if (value.kind === 'ratio') return clamp(value.value, 0, 1);
  if (value.kind === 'percent' || value.kind === 'number') return clamp(value.value / 100, 0, 1);
  return 0;
}

function selectBand(value: number, bands: MetricBand[]): string | null {
  return bands.find((band) => value <= band.max)?.id ?? null;
}

function toBandMetricId(metric: string): string {
  return metric.endsWith('_percent') ? metric.replace(/_percent$/, '_band') : `${metric}.band`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
