import type { NestLayoutManifest, NestPackageManifest, PackageFileEntry } from '@codexpet/core';

export interface BuiltInNestFixture {
  id: string;
  packageManifest: NestPackageManifest;
  nestLayout: NestLayoutManifest;
  files: PackageFileEntry[];
  assets: Record<string, string>;
}

const transparentPixel =
  'data:image/gif;base64,R0lGODlhAQABAPAAAP///wAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw==';

function makeFixture(
  id: string,
  name: string,
  nestLayout: NestLayoutManifest,
  extraAssets: string[] = [],
): BuiltInNestFixture {
  const assets = ['preview.png', ...nestLayout.layers.map((layer) => layer.src), ...extraAssets];
  return {
    id,
    packageManifest: {
      type: 'codexpet.nest',
      schemaVersion: nestLayout.schemaVersion,
      id,
      name,
      version: '0.1.0',
      author: 'CodexPet',
      description: `${name} renderer fixture.`,
      preview: 'preview.png',
      layout: 'nest.json',
      tags: ['built-in', 'fixture'],
    },
    nestLayout,
    files: [
      { path: 'codexpet-package.json', sizeBytes: 512 },
      { path: 'nest.json', sizeBytes: 1024 },
      ...assets.map((path) => ({ path, sizeBytes: 128 })),
    ],
    assets: Object.fromEntries(assets.map((path) => [path, transparentPixel])),
  };
}

export const builtInNestFixtures: BuiltInNestFixture[] = [
  makeFixture('default', 'Default Nest', {
    schemaVersion: '1.0.0',
    canvas: { width: 320, height: 120 },
    layers: [
      {
        id: 'bg',
        type: 'image',
        src: 'assets/default-bg.png',
        frame: { x: 0, y: 0, width: 320, height: 120 },
      },
      {
        id: 'fg',
        type: 'image',
        src: 'assets/default-fg.png',
        frame: { x: 0, y: 72, width: 320, height: 48 },
      },
    ],
    widgetSlots: {
      clock: { x: 16, y: 14, width: 92, height: 24 },
      usage: { x: 212, y: 14, width: 92, height: 24 },
    },
  }),
  makeFixture('capacity-orbit-nest', 'Capacity Orbit Nest', {
    schemaVersion: '1.1.0',
    canvas: { width: 320, height: 160 },
    layers: [
      {
        id: 'orbit-bg',
        type: 'image',
        src: 'assets/orbit-bg.png',
        frame: { x: 0, y: 0, width: 320, height: 160 },
      },
    ],
    widgetSlots: { usage: { x: 132, y: 52, width: 56, height: 56 } },
    metricBands: {
      'usage.primary.remaining_percent': [
        { id: 'empty', max: 0 },
        { id: 'low', max: 25 },
        { id: 'medium', max: 50 },
        { id: 'high', max: 75 },
        { id: 'full', max: 100 },
      ],
    },
    elements: [
      {
        id: 'quota-ring',
        type: 'metricGauge',
        metric: 'usage.primary.remaining_ratio',
        renderer: 'ringStroke',
        frame: { x: 118, y: 38, width: 84, height: 84 },
        style: { fillColor: '#64d2ff', trackColor: '#143244' },
      },
      {
        id: 'quota-label',
        type: 'metricText',
        metric: 'usage.primary.remaining_percent',
        frame: { x: 122, y: 124, width: 76, height: 18 },
        style: { suffix: '%', fallbackText: 'Usage ?' },
      },
    ],
  }),
  makeFixture('basket-pomodoro-nest', 'Basket Pomodoro Nest', {
    schemaVersion: '1.1.0',
    canvas: { width: 300, height: 150 },
    layers: [
      {
        id: 'basket-bg',
        type: 'image',
        src: 'assets/basket-bg.png',
        frame: { x: 0, y: 0, width: 300, height: 150 },
      },
    ],
    widgetSlots: { pomodoro: { x: 96, y: 18, width: 108, height: 28 } },
    elements: [
      {
        id: 'time-label',
        type: 'metricText',
        metric: 'system.time.hhmm',
        frame: { x: 112, y: 54, width: 76, height: 18 },
        style: { fallbackText: '--:--' },
      },
    ],
  }),
  makeFixture(
    'legend-status-nest',
    'Legend Status Nest',
    {
      schemaVersion: '1.1.0',
      canvas: { width: 340, height: 180 },
      layers: [
        {
          id: 'legend-bg',
          type: 'image',
          src: 'assets/legend-bg.png',
          frame: { x: 0, y: 0, width: 340, height: 180 },
        },
      ],
      metricBands: {
        'usage.primary.remaining_percent': [
          { id: 'low', max: 25 },
          { id: 'mid', max: 65 },
          { id: 'full', max: 100 },
        ],
      },
      elements: [
        {
          id: 'mana-orb',
          type: 'metricGauge',
          metric: 'usage.primary.remaining_ratio',
          renderer: 'circleFill',
          frame: { x: 244, y: 102, width: 54, height: 54 },
          style: { fillColor: '#3388ff', trackColor: '#071b38' },
        },
        {
          id: 'quota-badge',
          type: 'variantImage',
          metric: 'usage.primary.remaining_band',
          variants: {
            low: 'assets/badge-low.png',
            mid: 'assets/badge-mid.png',
            full: 'assets/badge-full.png',
          },
          fallback: 'assets/badge-mid.png',
          frame: { x: 40, y: 24, width: 32, height: 32 },
        },
      ],
    },
    ['assets/badge-low.png', 'assets/badge-mid.png', 'assets/badge-full.png'],
  ),
  makeFixture('nest-terminal', 'Nest Terminal', {
    schemaVersion: '1.1.0',
    canvas: { width: 360, height: 180 },
    layers: [
      {
        id: 'terminal-bg',
        type: 'image',
        src: 'assets/terminal-bg.png',
        frame: { x: 0, y: 0, width: 360, height: 180 },
      },
    ],
    widgetSlots: { clock: { x: 30, y: 24, width: 100, height: 22 } },
    elements: [
      {
        id: 'terminal-time',
        type: 'metricText',
        metric: 'system.time.hhmm',
        frame: { x: 34, y: 54, width: 90, height: 20 },
        style: { prefix: 'time ', fallbackText: 'time --:--' },
      },
      {
        id: 'usage-bar',
        type: 'metricGauge',
        metric: 'usage.primary.remaining_ratio',
        renderer: 'linearBar',
        frame: { x: 34, y: 88, width: 180, height: 12 },
        style: { fillColor: '#00ff88', trackColor: '#07331f' },
      },
    ],
  }),
];

export function getBuiltInNestFixture(id: string): BuiltInNestFixture | undefined {
  return builtInNestFixtures.find((fixture) => fixture.id === id);
}
