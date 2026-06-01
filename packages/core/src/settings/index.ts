export const CURRENT_SETTINGS_SCHEMA_VERSION = 2;

export type OverlayMode = 'follow-codex' | 'standalone-fixed' | 'standalone-roam';

export interface StandalonePosition {
  x: number;
  y: number;
  displayId?: string;
}

export interface QuickActionSettings {
  id: string;
  name: string;
  icon?: string;
  kind: 'url' | 'app' | 'shell' | 'shortcut' | 'windows-uri';
  target: string;
  enabled: boolean;
  requireConfirm: boolean;
  platform?: 'macos' | 'windows' | 'linux' | 'all';
}

export interface SyncDeviceMetadata {
  deviceId: string;
  platform: 'macos' | 'windows' | 'linux' | 'unknown';
  appVersion: string;
  lastSeenAt?: string;
}

export interface SyncSettingsMetadata {
  enabled: boolean;
  device?: SyncDeviceMetadata;
  lastSyncedAt?: string;
}

export interface CodexPetSettings {
  schemaVersion: number;
  activeNestId: string | null;
  overlayMode: OverlayMode;
  standalonePosition: StandalonePosition;
  alwaysOnTop: boolean;
  clickThrough: boolean;
  widgetConfigs: Record<string, unknown>;
  managedPetIds: string[];
  managedNestIds: string[];
  quickActions: QuickActionSettings[];
  sync: SyncSettingsMetadata;
  language: string;
  locale: string;
}

export interface SettingsMigrationResult {
  settings: CodexPetSettings;
  migrated: boolean;
  usedFallback: boolean;
  fromVersion?: number;
  errors: string[];
}

export function createDefaultSettings(): CodexPetSettings {
  return {
    schemaVersion: CURRENT_SETTINGS_SCHEMA_VERSION,
    activeNestId: null,
    overlayMode: 'follow-codex',
    standalonePosition: { x: 100, y: 100 },
    alwaysOnTop: true,
    clickThrough: false,
    widgetConfigs: {},
    managedPetIds: [],
    managedNestIds: [],
    quickActions: [],
    sync: { enabled: false },
    language: 'system',
    locale: 'system',
  };
}

export function loadSettings(value: unknown): SettingsMigrationResult {
  const defaults = createDefaultSettings();
  if (!isRecord(value)) {
    return {
      settings: defaults,
      migrated: false,
      usedFallback: true,
      errors: ['Settings must be an object'],
    };
  }

  const version = typeof value.schemaVersion === 'number' ? value.schemaVersion : 1;
  if (version > CURRENT_SETTINGS_SCHEMA_VERSION) {
    return {
      settings: defaults,
      migrated: false,
      usedFallback: true,
      errors: [`Unsupported settings schemaVersion ${version}`],
    };
  }

  try {
    const settings =
      version === CURRENT_SETTINGS_SCHEMA_VERSION
        ? normalizeCurrent(value)
        : migrateSettings(value, version);
    return {
      settings,
      migrated: version !== CURRENT_SETTINGS_SCHEMA_VERSION,
      usedFallback: false,
      fromVersion: version,
      errors: [],
    };
  } catch (error) {
    return {
      settings: defaults,
      migrated: false,
      usedFallback: true,
      errors: [error instanceof Error ? error.message : String(error)],
    };
  }
}

function migrateSettings(value: Record<string, unknown>, version: number): CodexPetSettings {
  let next = {
    ...createDefaultSettings(),
    ...coercePartialSettings(value),
    schemaVersion: version,
  };
  if (version === 1) {
    next = {
      ...next,
      schemaVersion: 2,
      language: typeof value.language === 'string' ? value.language : 'system',
      locale: typeof value.locale === 'string' ? value.locale : 'system',
      sync: isRecord(value.sync) ? coerceSync(value.sync) : { enabled: false },
    };
  }
  return normalizeCurrent(next);
}

function normalizeCurrent(value: Record<string, unknown>): CodexPetSettings {
  const settings = { ...createDefaultSettings(), ...coercePartialSettings(value) };
  settings.schemaVersion = CURRENT_SETTINGS_SCHEMA_VERSION;
  return settings;
}

function coercePartialSettings(value: Record<string, unknown>): Partial<CodexPetSettings> {
  return {
    activeNestId: typeof value.activeNestId === 'string' ? value.activeNestId : null,
    overlayMode: isOverlayMode(value.overlayMode) ? value.overlayMode : 'follow-codex',
    standalonePosition: coercePosition(value.standalonePosition),
    alwaysOnTop: typeof value.alwaysOnTop === 'boolean' ? value.alwaysOnTop : true,
    clickThrough: typeof value.clickThrough === 'boolean' ? value.clickThrough : false,
    widgetConfigs: isRecord(value.widgetConfigs) ? value.widgetConfigs : {},
    managedPetIds: stringArray(value.managedPetIds),
    managedNestIds: stringArray(value.managedNestIds),
    quickActions: Array.isArray(value.quickActions) ? value.quickActions.filter(isQuickAction) : [],
    sync: isRecord(value.sync) ? coerceSync(value.sync) : { enabled: false },
    language: typeof value.language === 'string' ? value.language : 'system',
    locale: typeof value.locale === 'string' ? value.locale : 'system',
  };
}

function coercePosition(value: unknown): StandalonePosition {
  if (!isRecord(value) || typeof value.x !== 'number' || typeof value.y !== 'number') {
    return { x: 100, y: 100 };
  }
  return {
    x: value.x,
    y: value.y,
    displayId: typeof value.displayId === 'string' ? value.displayId : undefined,
  };
}

function coerceSync(value: Record<string, unknown>): SyncSettingsMetadata {
  return {
    enabled: typeof value.enabled === 'boolean' ? value.enabled : false,
    device: isRecord(value.device) ? coerceDevice(value.device) : undefined,
    lastSyncedAt: typeof value.lastSyncedAt === 'string' ? value.lastSyncedAt : undefined,
  };
}

function coerceDevice(value: Record<string, unknown>): SyncDeviceMetadata {
  return {
    deviceId: typeof value.deviceId === 'string' ? value.deviceId : 'unknown',
    platform: isPlatform(value.platform) ? value.platform : 'unknown',
    appVersion: typeof value.appVersion === 'string' ? value.appVersion : 'unknown',
    lastSeenAt: typeof value.lastSeenAt === 'string' ? value.lastSeenAt : undefined,
  };
}

function isQuickAction(value: unknown): value is QuickActionSettings {
  return (
    isRecord(value) &&
    typeof value.id === 'string' &&
    typeof value.name === 'string' &&
    typeof value.target === 'string' &&
    typeof value.enabled === 'boolean' &&
    typeof value.requireConfirm === 'boolean' &&
    ['url', 'app', 'shell', 'shortcut', 'windows-uri'].includes(String(value.kind))
  );
}

function isOverlayMode(value: unknown): value is OverlayMode {
  return value === 'follow-codex' || value === 'standalone-fixed' || value === 'standalone-roam';
}

function isPlatform(value: unknown): value is SyncDeviceMetadata['platform'] {
  return value === 'macos' || value === 'windows' || value === 'linux' || value === 'unknown';
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string')
    : [];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
