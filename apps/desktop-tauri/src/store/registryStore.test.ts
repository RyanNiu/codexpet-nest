import { describe, expect, it, vi } from 'vitest';
import { invoke } from '@tauri-apps/api/core';
import { createDefaultPackageRegistry } from '@codexpet/core';
import {
  builtInNestRegistryEntries,
  getEnabledNestEntries,
  getNestEntries,
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

  it('should not save when loaded registry is unchanged after built-in merge', async () => {
    const registry = { schemaVersion: 1, packages: builtInNestRegistryEntries };
    vi.mocked(invoke).mockImplementation((command) => {
      if (command === 'load_local_registry') return Promise.resolve(registry);
      if (command === 'save_local_registry') return Promise.resolve(undefined);
      return Promise.reject(new Error(`Unhandled invoke command: ${String(command)}`));
    });

    await useRegistryStore.getState().load();

    expect(vi.mocked(invoke)).not.toHaveBeenCalledWith('save_local_registry', expect.anything());
  });

  it('should keep disabled nests visible but out of enabled choices', () => {
    const disabledNest = { ...builtInNestRegistryEntries[0]!, id: 'disabled-nest', enabled: false };
    const registry = { schemaVersion: 1, packages: [...builtInNestRegistryEntries, disabledNest] };

    expect(getNestEntries(registry).map((entry) => entry.id)).toContain('disabled-nest');
    expect(getEnabledNestEntries(registry).map((entry) => entry.id)).not.toContain('disabled-nest');
  });

  it('should refresh registry after importing a local package', async () => {
    const imported = {
      ...builtInNestRegistryEntries[0]!,
      id: 'imported-nest',
      name: 'Imported Nest',
      manifestPath: '/tmp/imported/codexpet-package.json',
      assetRoot: '/tmp/imported',
    };
    vi.mocked(invoke).mockImplementation((command) => {
      if (command === 'import_local_package') {
        return Promise.resolve({ schemaVersion: 1, packages: [imported] });
      }
      return Promise.reject(new Error(`Unhandled invoke command: ${String(command)}`));
    });

    await useRegistryStore.getState().importPackage('/tmp/imported');

    expect(
      useRegistryStore.getState().registry.packages.some((entry) => entry.id === 'imported-nest'),
    ).toBe(true);
  });
});
