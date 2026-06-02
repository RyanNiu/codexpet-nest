export const CURRENT_PACKAGE_REGISTRY_SCHEMA_VERSION = 1;

export type LocalPackageType = 'pet' | 'nest';

export interface LocalPackageEntry {
  id: string;
  type: LocalPackageType;
  version: string;
  name: string;
  manifestPath: string;
  assetRoot: string;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface LocalPackageRegistry {
  schemaVersion: number;
  packages: LocalPackageEntry[];
}

export interface PackageRegistryLoadResult {
  registry: LocalPackageRegistry;
  migrated: boolean;
  usedFallback: boolean;
  fromVersion?: number;
  errors: string[];
}

export function createDefaultPackageRegistry(): LocalPackageRegistry {
  return {
    schemaVersion: CURRENT_PACKAGE_REGISTRY_SCHEMA_VERSION,
    packages: [],
  };
}

export function loadPackageRegistry(value: unknown): PackageRegistryLoadResult {
  const defaults = createDefaultPackageRegistry();
  if (!isRecord(value)) {
    return {
      registry: defaults,
      migrated: false,
      usedFallback: true,
      errors: ['Package registry must be an object'],
    };
  }

  const version = typeof value.schemaVersion === 'number' ? value.schemaVersion : 0;
  if (version > CURRENT_PACKAGE_REGISTRY_SCHEMA_VERSION) {
    return {
      registry: defaults,
      migrated: false,
      usedFallback: true,
      errors: [`Unsupported package registry schemaVersion ${version}`],
    };
  }

  try {
    const registry = normalizeRegistry(value);
    return {
      registry,
      migrated: version !== CURRENT_PACKAGE_REGISTRY_SCHEMA_VERSION,
      usedFallback: false,
      fromVersion: version,
      errors: [],
    };
  } catch (error) {
    return {
      registry: defaults,
      migrated: false,
      usedFallback: true,
      errors: [error instanceof Error ? error.message : String(error)],
    };
  }
}

export function validatePackageRegistry(value: unknown): PackageRegistryLoadResult {
  return loadPackageRegistry(value);
}

function normalizeRegistry(value: Record<string, unknown>): LocalPackageRegistry {
  const entries = Array.isArray(value.packages) ? value.packages.map(coerceEntry) : [];
  return {
    schemaVersion: CURRENT_PACKAGE_REGISTRY_SCHEMA_VERSION,
    packages: dedupeById(entries),
  };
}

function coerceEntry(value: unknown): LocalPackageEntry {
  if (!isRecord(value)) throw new Error('Package registry entry must be an object');
  const id = requiredString(value, 'id');
  const type = coerceType(value.type);
  return {
    id,
    type,
    version: requiredString(value, 'version'),
    name: requiredString(value, 'name'),
    manifestPath: requiredString(value, 'manifestPath'),
    assetRoot: requiredString(value, 'assetRoot'),
    enabled: typeof value.enabled === 'boolean' ? value.enabled : true,
    createdAt: coerceTimestamp(value.createdAt),
    updatedAt: coerceTimestamp(value.updatedAt),
  };
}

function dedupeById(entries: LocalPackageEntry[]): LocalPackageEntry[] {
  return Array.from(new Map(entries.map((entry) => [entry.id, entry])).values());
}

function coerceType(value: unknown): LocalPackageType {
  if (value === 'pet' || value === 'nest') return value;
  if (value === 'codexpet.pet') return 'pet';
  if (value === 'codexpet.nest') return 'nest';
  throw new Error('Package registry entry type must be pet or nest');
}

function coerceTimestamp(value: unknown): string {
  return typeof value === 'string' && value.length > 0 ? value : new Date(0).toISOString();
}

function requiredString(value: Record<string, unknown>, key: string): string {
  const field = value[key];
  if (typeof field !== 'string' || field.length === 0) {
    throw new Error(`Package registry entry requires ${key}`);
  }
  return field;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
