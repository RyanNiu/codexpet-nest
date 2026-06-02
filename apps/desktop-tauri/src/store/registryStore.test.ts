import { describe, expect, it, vi } from 'vitest';
import { invoke } from '@tauri-apps/api/core';
import { createDefaultPackageRegistry } from '@codexpet/core';
import {
  builtInNestRegistryEntries,
  getEnabledNestEntries,
  resolveActiveNestEntry,
  useRegistryStore,
} from './registryStore';

describe('useRegistryStore', () => {
  it('should load and merge built-in nest registry entries', async () => {
    vi.mocked(invoke).mockImplementationOnce(() => Promise.resolve(createDefaultPackageRegistry()));

    await useRegistryStore.getState().load();

    const nests = getEnabledNestEntries(useRegistryStore.getState().registry);
    expect(nests.map((entry) => entry.id)).toEqual([
      'default',
      'capacity-orbit-nest',
      'basket-pomodoro-nest',
    ]);
  });

  it('should resolve missing active nest to default fallback', () => {
    const result = resolveActiveNestEntry(
      { schemaVersion: 1, packages: builtInNestRegistryEntries },
      'missing-nest',
    );

    expect(result.fallback).toBe(true);
    expect(result.entry?.id).toBe('default');
  });
});
