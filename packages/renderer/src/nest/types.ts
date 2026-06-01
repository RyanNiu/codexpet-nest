import type { NestLayoutManifest, Rect, WidgetSlot } from '@codexpet/core';
import type { MetricSnapshot, MetricValue } from '../metrics/types';

export type AssetResolver = (path: string) => string | null;

export interface RenderModelInput {
  theme: NestLayoutManifest;
  metrics: MetricSnapshot;
  resolveAsset: AssetResolver;
}

export interface RenderIssue {
  code: 'missing_asset' | 'metric_unavailable';
  message: string;
  path?: string;
  metric?: string;
}

export interface RenderLayer {
  id: string;
  type: 'image';
  src: string;
  resolvedSrc: string | null;
  frame: Rect;
}

export interface RenderWidgetSlot extends WidgetSlot {
  id: string;
}

export type RenderElement =
  | {
      id: string;
      type: 'staticImage';
      src: string;
      resolvedSrc: string | null;
      frame: Rect;
      style?: Record<string, unknown>;
    }
  | {
      id: string;
      type: 'variantImage';
      metric: string;
      metricValue: MetricValue;
      selectedVariant: string | null;
      resolvedSrc: string | null;
      frame: Rect;
      style?: Record<string, unknown>;
    }
  | {
      id: string;
      type: 'metricText';
      metric: string;
      metricValue: MetricValue;
      text: string;
      frame: Rect;
      style?: Record<string, unknown>;
    }
  | {
      id: string;
      type: 'metricGauge';
      metric: string;
      metricValue: MetricValue;
      renderer: 'ringStroke' | 'linearBar' | 'circleFill';
      value: number;
      unavailable: boolean;
      frame: Rect;
      style?: Record<string, unknown>;
    };

export interface NestRenderModel {
  canvas: { width: number; height: number };
  layers: RenderLayer[];
  widgetSlots: RenderWidgetSlot[];
  elements: RenderElement[];
  metricBands: Record<string, string>;
  issues: RenderIssue[];
}
