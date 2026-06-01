import { describe, expect, it } from 'vitest';
import { MAX_IMAGE_BYTES, MAX_PACKAGE_BYTES, validatePackage } from './validator';
import type { NestLayoutManifest, PackageFileEntry } from './types';

const petPackageManifest = {
  type: 'codexpet.pet',
  schemaVersion: '1.0',
  id: 'codie',
  name: 'Codie',
  version: '1.0.0',
  author: 'CodexPet',
  description: 'A tiny coding companion.',
  manifest: 'pet.json',
  spritesheet: 'spritesheet.webp',
  preview: 'preview.png',
  tags: ['robot'],
};

const nestPackageManifest = {
  type: 'codexpet.nest',
  schemaVersion: '1.0.0',
  id: 'minimal-glass',
  name: 'Minimal Glass',
  version: '1.0.0',
  author: 'CodexPet',
  description: 'A clean glass nest.',
  preview: 'preview.png',
  layout: 'nest.json',
  tags: ['minimal'],
};

const petManifest = {
  name: 'Codie',
  spritesheet: 'spritesheet.webp',
  frameWidth: 64,
  frameHeight: 64,
  animations: {},
};

const v1NestLayout: NestLayoutManifest = {
  schemaVersion: '1.0.0',
  canvas: { width: 200, height: 150 },
  layers: [
    {
      id: 'bg',
      type: 'image',
      src: 'assets/bg.png',
      frame: { x: 0, y: 0, width: 200, height: 150 },
    },
  ],
  widgetSlots: {
    clock: { x: 10, y: 10, width: 100, height: 24 },
  },
};

const v11NestLayout: NestLayoutManifest = {
  ...v1NestLayout,
  schemaVersion: '1.1.0',
  metricBands: {
    'usage.primary.remaining_percent': [
      { id: 'low', max: 25 },
      { id: 'full', max: 100 },
    ],
  },
  elements: [
    {
      id: 'quota',
      type: 'metricGauge',
      metric: 'usage.primary.remaining_ratio',
      renderer: 'circleFill',
      frame: { x: 20, y: 20, width: 40, height: 40 },
    },
    {
      id: 'label',
      type: 'metricText',
      metric: 'system.time.hhmm',
      frame: { x: 70, y: 20, width: 80, height: 20 },
    },
  ],
};

const petFiles: PackageFileEntry[] = [
  { path: 'codexpet-package.json', sizeBytes: 512 },
  { path: 'pet.json', sizeBytes: 512 },
  { path: 'spritesheet.webp', sizeBytes: 1000 },
  { path: 'preview.png', sizeBytes: 1000 },
  { path: 'README.md', sizeBytes: 100 },
  { path: 'LICENSE', sizeBytes: 100 },
];

const nestFiles: PackageFileEntry[] = [
  { path: 'codexpet-package.json', sizeBytes: 512 },
  { path: 'nest.json', sizeBytes: 512 },
  { path: 'preview.png', sizeBytes: 1000 },
  { path: 'assets/bg.png', sizeBytes: 1000 },
];

describe('validatePackage', () => {
  it('accepts a valid pet package manifest', () => {
    const result = validatePackage({
      expectedType: 'codexpet.pet',
      packageSizeBytes: 4096,
      files: petFiles,
      packageManifest: petPackageManifest,
      petManifest,
    });

    expect(result.ok).toBe(true);
    expect(result.value?.type).toBe('codexpet.pet');
  });

  it('accepts a valid nest package manifest', () => {
    const result = validatePackage({
      expectedType: 'codexpet.nest',
      packageSizeBytes: 4096,
      files: nestFiles,
      packageManifest: nestPackageManifest,
      nestLayout: v1NestLayout,
    });

    expect(result.ok).toBe(true);
    expect(result.value?.type).toBe('codexpet.nest');
  });

  it('rejects a missing package manifest', () => {
    const result = validatePackage({
      packageSizeBytes: 4096,
      files: nestFiles,
      nestLayout: v1NestLayout,
    });
    expect(result.ok).toBe(false);
    expect(result.errors).toContainEqual(expect.objectContaining({ code: 'missing_manifest' }));
  });

  it('rejects an invalid package type', () => {
    const result = validatePackage({
      expectedType: 'codexpet.nest',
      packageSizeBytes: 4096,
      files: nestFiles,
      packageManifest: { ...nestPackageManifest, type: 'codexpet.pet' },
      nestLayout: v1NestLayout,
    });
    expect(result.errors).toContainEqual(expect.objectContaining({ code: 'invalid_package_type' }));
  });

  it('rejects path traversal', () => {
    const result = validatePackage({
      packageSizeBytes: 4096,
      files: [...nestFiles, { path: '../evil.png', sizeBytes: 1 }],
      packageManifest: nestPackageManifest,
      nestLayout: v1NestLayout,
    });
    expect(result.errors).toContainEqual(
      expect.objectContaining({ code: 'unsafe_path', path: '../evil.png' }),
    );
  });

  it('rejects unsafe file extensions', () => {
    const result = validatePackage({
      packageSizeBytes: 4096,
      files: [
        ...nestFiles,
        { path: 'install.sh', sizeBytes: 1 },
        { path: 'tool.exe', sizeBytes: 1 },
      ],
      packageManifest: nestPackageManifest,
      nestLayout: v1NestLayout,
    });
    expect(result.errors.filter((error) => error.code === 'unsafe_extension')).toHaveLength(2);
  });

  it('rejects remote URL resources', () => {
    const result = validatePackage({
      packageSizeBytes: 4096,
      files: nestFiles,
      packageManifest: { ...nestPackageManifest, preview: 'https://example.com/preview.png' },
      nestLayout: v1NestLayout,
    });
    expect(result.errors).toContainEqual(expect.objectContaining({ code: 'remote_url' }));
  });

  it('rejects a missing preview file reference', () => {
    const result = validatePackage({
      packageSizeBytes: 4096,
      files: petFiles.filter((file) => file.path !== 'preview.png'),
      packageManifest: petPackageManifest,
      petManifest,
    });

    expect(result.errors).toContainEqual(
      expect.objectContaining({ code: 'missing_required_file', path: 'preview.png' }),
    );
  });

  it('rejects a missing pet spritesheet file reference', () => {
    const result = validatePackage({
      packageSizeBytes: 4096,
      files: petFiles.filter((file) => file.path !== 'spritesheet.webp'),
      packageManifest: petPackageManifest,
      petManifest,
    });

    expect(result.errors).toContainEqual(
      expect.objectContaining({ code: 'missing_required_file', path: 'spritesheet.webp' }),
    );
  });

  it('rejects a missing nest layer asset reference', () => {
    const result = validatePackage({
      packageSizeBytes: 4096,
      files: nestFiles.filter((file) => file.path !== 'assets/bg.png'),
      packageManifest: nestPackageManifest,
      nestLayout: v1NestLayout,
    });

    expect(result.errors).toContainEqual(
      expect.objectContaining({ code: 'missing_required_file', path: 'assets/bg.png' }),
    );
  });

  it('rejects a missing variantImage asset reference', () => {
    const layout: NestLayoutManifest = {
      ...v11NestLayout,
      elements: [
        {
          id: 'sky',
          type: 'variantImage',
          metric: 'system.time.day_period',
          variants: {
            day: 'assets/day.png',
            night: 'assets/night.png',
          },
          fallback: 'assets/day.png',
          frame: { x: 0, y: 0, width: 32, height: 32 },
        },
      ],
    };

    const result = validatePackage({
      packageSizeBytes: 4096,
      files: [...nestFiles, { path: 'assets/day.png', sizeBytes: 1000 }],
      packageManifest: nestPackageManifest,
      nestLayout: layout,
    });

    expect(result.errors).toContainEqual(
      expect.objectContaining({ code: 'missing_required_file', path: 'assets/night.png' }),
    );
  });

  it('rejects oversized package and image resources', () => {
    const result = validatePackage({
      packageSizeBytes: MAX_PACKAGE_BYTES + 1,
      files: [...nestFiles, { path: 'assets/huge.png', sizeBytes: MAX_IMAGE_BYTES + 1 }],
      packageManifest: nestPackageManifest,
      nestLayout: v1NestLayout,
    });
    expect(result.errors).toContainEqual(expect.objectContaining({ code: 'oversized_package' }));
    expect(result.errors).toContainEqual(expect.objectContaining({ code: 'oversized_image' }));
  });

  it('accepts v1.0 nest layout with widget slots', () => {
    const result = validatePackage({
      expectedType: 'codexpet.nest',
      packageSizeBytes: 4096,
      files: nestFiles,
      packageManifest: nestPackageManifest,
      nestLayout: v1NestLayout,
    });
    expect(result.ok).toBe(true);
  });

  it('accepts v1.1 elements and metricBands', () => {
    const result = validatePackage({
      expectedType: 'codexpet.nest',
      packageSizeBytes: 4096,
      files: nestFiles,
      packageManifest: nestPackageManifest,
      nestLayout: v11NestLayout,
    });
    expect(result.ok).toBe(true);
  });
});
