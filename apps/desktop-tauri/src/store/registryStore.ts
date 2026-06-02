import { invoke } from '@tauri-apps/api/core';
import { create } from 'zustand';
import {
  createDefaultPackageRegistry,
  loadPackageRegistry,
  type LocalPackageEntry,
  type LocalPackageRegistry,
} from '@codexpet/core';
import { builtInNestFixtures } from '@codexpet/renderer/fixtures/nests';

const builtInRegistryTimestamp = '2026-01-01T00:00:00.000Z';

interface RegistryState {
  registry: LocalPackageRegistry;
  isLoading: boolean;
  isSaving: boolean;
  error: string | null;
  load: () => Promise<void>;
  save: (registry: LocalPackageRegistry) => Promise<void>;
  importPackage: (importPath: string) => Promise<void>;
}

export const builtInNestRegistryEntries: LocalPackageEntry[] = builtInNestFixtures
  .filter((fixture) =>
    ['default', 'capacity-orbit-nest', 'basket-pomodoro-nest'].includes(fixture.id),
  )
  .map((fixture) => ({
    id: fixture.id,
    type: 'nest',
    version: fixture.packageManifest.version,
    name: fixture.packageManifest.name ?? fixture.id,
    manifestPath: `builtin/nests/${fixture.id}/codexpet-package.json`,
    assetRoot: `builtin/nests/${fixture.id}`,
    enabled: true,
    createdAt: builtInRegistryTimestamp,
    updatedAt: builtInRegistryTimestamp,
  }));

export const useRegistryStore = create<RegistryState>((set) => ({
  registry: mergeBuiltInEntries(createDefaultPackageRegistry()),
  isLoading: true,
  isSaving: false,
  error: null,
  load: async () => {
    set({ isLoading: true, error: null });
    try {
      const raw = await invoke<unknown | null>('load_local_registry');
      const result =
        raw === null
          ? loadPackageRegistry(createDefaultPackageRegistry())
          : loadPackageRegistry(raw);
      const registry = mergeBuiltInEntries(result.registry);
      set({ registry, isLoading: false, error: null });

      if (
        raw === null ||
        result.migrated ||
        result.usedFallback ||
        !registriesEqual(registry, result.registry)
      ) {
        await invoke('save_local_registry', { registry });
      }
    } catch (error) {
      set({
        registry: mergeBuiltInEntries(createDefaultPackageRegistry()),
        isLoading: false,
        error: String(error),
      });
    }
  },
  save: async (registry) => {
    const next = mergeBuiltInEntries(registry);
    set({ isSaving: true, error: null });
    try {
      await invoke('save_local_registry', { registry: next });
      set({ registry: next, isSaving: false, error: null });
    } catch (error) {
      set({ isSaving: false, error: String(error) });
      throw error;
    }
  },
  importPackage: async (importPath) => {
    set({ isSaving: true, error: null });
    try {
      const raw = await invoke<unknown>('import_local_package', { importPath });
      const result = loadPackageRegistry(raw);
      const registry = mergeBuiltInEntries(result.registry);
      set({ registry, isSaving: false, error: null });
    } catch (error) {
      set({ isSaving: false, error: String(error) });
      throw error;
    }
  },
}));

export function getNestEntries(registry: LocalPackageRegistry): LocalPackageEntry[] {
  return registry.packages.filter((entry) => entry.type === 'nest');
}

export function getEnabledNestEntries(registry: LocalPackageRegistry): LocalPackageEntry[] {
  return getNestEntries(registry).filter((entry) => entry.enabled);
}

export function resolveActiveNestEntry(
  registry: LocalPackageRegistry,
  activeNestId: string | null,
): { entry: LocalPackageEntry | null; fallback: boolean } {
  const enabledNests = getEnabledNestEntries(registry);
  const active = activeNestId ? enabledNests.find((entry) => entry.id === activeNestId) : null;
  if (active) return { entry: active, fallback: false };
  return {
    entry: enabledNests.find((entry) => entry.id === 'default') ?? enabledNests[0] ?? null,
    fallback: activeNestId !== null,
  };
}

function mergeBuiltInEntries(registry: LocalPackageRegistry): LocalPackageRegistry {
  const byId = new Map(registry.packages.map((entry) => [entry.id, entry]));
  for (const entry of builtInNestRegistryEntries) {
    const existing = byId.get(entry.id);
    byId.set(
      entry.id,
      existing ? { ...entry, ...existing, type: entry.type, enabled: existing.enabled } : entry,
    );
  }
  return {
    ...registry,
    packages: Array.from(byId.values()),
  };
}

function registriesEqual(left: LocalPackageRegistry, right: LocalPackageRegistry): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}
