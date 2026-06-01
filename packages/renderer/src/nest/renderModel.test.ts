import { describe, expect, it } from 'vitest';
import type { NestLayoutManifest } from '@codexpet/core';
import { buildNestRenderModel } from './renderModel';
import type { AssetResolver } from './types';
import type { MetricSnapshot } from '../metrics/types';

const resolveAsset: AssetResolver = (path) => `asset://${path}`;

const metrics: MetricSnapshot = {
  'system.time.day_period': { kind: 'enumeration', value: 'night' },
  'system.time.hhmm': { kind: 'text', value: '21:45' },
  'usage.primary.remaining_percent': { kind: 'percent', value: 20 },
  'usage.primary.remaining_ratio': { kind: 'ratio', value: 0.2 },
};

const baseTheme: NestLayoutManifest = {
  schemaVersion: '1.1.0',
  canvas: { width: 320, height: 180 },
  layers: [
    {
      id: 'bg',
      type: 'image',
      src: 'assets/bg.png',
      frame: { x: 0, y: 0, width: 320, height: 180 },
    },
    {
      id: 'fg',
      type: 'image',
      src: 'assets/fg.png',
      frame: { x: 0, y: 120, width: 320, height: 60 },
    },
  ],
  widgetSlots: {
    clock: { x: 8, y: 8, width: 80, height: 24 },
  },
  metricBands: {
    'usage.primary.remaining_percent': [
      { id: 'low', max: 25 },
      { id: 'full', max: 100 },
    ],
  },
  elements: [],
};

describe('buildNestRenderModel', () => {
  it('preserves v1.0 layer ordering', () => {
    const model = buildNestRenderModel({
      theme: { ...baseTheme, schemaVersion: '1.0.0', elements: undefined },
      metrics,
      resolveAsset,
    });

    expect(model.layers.map((layer) => layer.id)).toEqual(['bg', 'fg']);
  });

  it('passes widgetSlots through as ordered entries', () => {
    const model = buildNestRenderModel({ theme: baseTheme, metrics, resolveAsset });

    expect(model.widgetSlots).toEqual([{ id: 'clock', x: 8, y: 8, width: 80, height: 24 }]);
  });

  it('resolves staticImage assets', () => {
    const model = buildNestRenderModel({
      theme: {
        ...baseTheme,
        elements: [
          {
            id: 'frame',
            type: 'staticImage',
            src: 'assets/frame.png',
            frame: { x: 0, y: 0, width: 50, height: 50 },
          },
        ],
      },
      metrics,
      resolveAsset,
    });

    expect(model.elements[0]).toMatchObject({
      type: 'staticImage',
      resolvedSrc: 'asset://assets/frame.png',
    });
  });

  it('selects variantImage resources from metric values', () => {
    const model = buildNestRenderModel({
      theme: {
        ...baseTheme,
        elements: [
          {
            id: 'sky',
            type: 'variantImage',
            metric: 'system.time.day_period',
            variants: { day: 'assets/day.png', night: 'assets/night.png' },
            fallback: 'assets/day.png',
            frame: { x: 0, y: 0, width: 32, height: 32 },
          },
        ],
      },
      metrics,
      resolveAsset,
    });

    expect(model.elements[0]).toMatchObject({
      type: 'variantImage',
      selectedVariant: 'assets/night.png',
    });
  });

  it('uses variantImage fallback when metric is unavailable', () => {
    const model = buildNestRenderModel({
      theme: {
        ...baseTheme,
        elements: [
          {
            id: 'sky',
            type: 'variantImage',
            metric: 'missing.metric',
            variants: { day: 'assets/day.png' },
            fallback: 'assets/fallback.png',
            frame: { x: 0, y: 0, width: 32, height: 32 },
          },
        ],
      },
      metrics,
      resolveAsset,
    });

    expect(model.elements[0]).toMatchObject({
      type: 'variantImage',
      selectedVariant: 'assets/fallback.png',
    });
    expect(model.issues).toContainEqual(
      expect.objectContaining({ code: 'metric_unavailable', metric: 'missing.metric' }),
    );
  });

  it('uses metricText unavailable fallback', () => {
    const model = buildNestRenderModel({
      theme: {
        ...baseTheme,
        elements: [
          {
            id: 'text',
            type: 'metricText',
            metric: 'missing.metric',
            frame: { x: 0, y: 0, width: 80, height: 20 },
            style: { fallbackText: '--' },
          },
        ],
      },
      metrics,
      resolveAsset,
    });

    expect(model.elements[0]).toMatchObject({ type: 'metricText', text: '--' });
  });

  it('uses metricGauge unavailable fallback', () => {
    const model = buildNestRenderModel({
      theme: {
        ...baseTheme,
        elements: [
          {
            id: 'gauge',
            type: 'metricGauge',
            metric: 'missing.metric',
            renderer: 'linearBar',
            frame: { x: 0, y: 0, width: 80, height: 10 },
          },
        ],
      },
      metrics,
      resolveAsset,
    });

    expect(model.elements[0]).toMatchObject({ type: 'metricGauge', value: 0, unavailable: true });
  });

  it('computes metricBands from percent metrics', () => {
    const model = buildNestRenderModel({ theme: baseTheme, metrics, resolveAsset });

    expect(model.metricBands['usage.primary.remaining_band']).toBe('low');
  });
});
