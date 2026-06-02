import { describe, expect, it } from 'vitest';
import {
  createDefaultPackageRegistry,
  createLocalPackageEntry,
  loadPackageRegistry,
  upsertLocalPackageEntry,
} from './index';

describe('package registry', () => {
  it('creates a default registry', () => {
    const registry = createDefaultPackageRegistry();

    expect(registry.schemaVersion).toBe(1);
    expect(registry.packages).toEqual([]);
  });

  it('loads valid local package entries', () => {
    const result = loadPackageRegistry({
      schemaVersion: 1,
      packages: [
        {
          id: 'default',
          type: 'nest',
          version: '0.1.0',
          name: 'Default Nest',
          manifestPath: 'builtin/default/codexpet-package.json',
          assetRoot: 'builtin/default',
          enabled: true,
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-01-01T00:00:00.000Z',
        },
      ],
    });

    expect(result.usedFallback).toBe(false);
    expect(result.registry.packages[0]?.id).toBe('default');
    expect(result.registry.packages[0]?.type).toBe('nest');
  });

  it('migrates legacy codexpet package type names', () => {
    const result = loadPackageRegistry({
      packages: [
        {
          id: 'pet-a',
          type: 'codexpet.pet',
          version: '1.0.0',
          name: 'Pet A',
          manifestPath: 'pet-a/codexpet-package.json',
          assetRoot: 'pet-a',
          enabled: true,
        },
      ],
    });

    expect(result.migrated).toBe(true);
    expect(result.registry.schemaVersion).toBe(1);
    expect(result.registry.packages[0]?.type).toBe('pet');
  });

  it('falls back for corrupted registries', () => {
    const result = loadPackageRegistry({
      schemaVersion: 1,
      packages: [{ id: 'broken', type: 'nest' }],
    });

    expect(result.usedFallback).toBe(true);
    expect(result.registry).toEqual(createDefaultPackageRegistry());
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('creates and upserts imported local package entries', () => {
    const entry = createLocalPackageEntry({
      id: 'imported-nest',
      type: 'codexpet.nest',
      version: '1.2.3',
      name: 'Imported Nest',
      manifestPath: '/tmp/imported/codexpet-package.json',
      assetRoot: '/tmp/imported',
      now: '2026-02-01T00:00:00.000Z',
    });

    const registry = upsertLocalPackageEntry(createDefaultPackageRegistry(), entry);

    expect(entry.type).toBe('nest');
    expect(entry.enabled).toBe(true);
    expect(registry.packages).toEqual([entry]);
  });

  it('preserves existing createdAt and enabled state when replacing an entry', () => {
    const existing = createLocalPackageEntry({
      id: 'imported-nest',
      type: 'nest',
      version: '1.0.0',
      name: 'Imported Nest',
      manifestPath: '/tmp/imported/codexpet-package.json',
      assetRoot: '/tmp/imported',
      enabled: false,
      now: '2026-02-01T00:00:00.000Z',
    });
    const next = createLocalPackageEntry({
      id: 'imported-nest',
      type: 'nest',
      version: '1.0.1',
      name: 'Imported Nest Updated',
      manifestPath: '/tmp/imported/codexpet-package.json',
      assetRoot: '/tmp/imported',
      existing,
      now: '2026-02-02T00:00:00.000Z',
    });

    expect(next.createdAt).toBe(existing.createdAt);
    expect(next.updatedAt).toBe('2026-02-02T00:00:00.000Z');
    expect(next.enabled).toBe(false);
  });
});
