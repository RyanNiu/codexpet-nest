export const CURRENT_SETTINGS_SCHEMA_VERSION = 3;

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
  kind: QuickActionType;
  target: string;
  enabled: boolean;
  requireConfirm: boolean;
  platform?: ActionPlatform;
}

export type WidgetType = 'metric' | 'action-list' | 'status';
export type WidgetSlotBinding = 'clock' | 'usage' | 'actions' | 'status' | string;
export type QuickActionType = 'url' | 'app' | 'shortcut' | 'shell-placeholder';
export type ActionPlatform = 'macos' | 'windows' | 'linux' | 'all';

export interface WidgetRuntimeConfig {
  id: string;
  type: WidgetType;
  enabled: boolean;
  slot: WidgetSlotBinding;
  metric?: string;
  actionIds?: string[];
  platform?: ActionPlatform;
}

export interface WidgetActionValidationResult {
  widgets: WidgetRuntimeConfig[];
  quickActions: QuickActionSettings[];
  errors: string[];
}

export const BUILT_IN_WIDGETS: WidgetRuntimeConfig[] = [
  {
    id: 'clock-widget',
    type: 'metric',
    enabled: true,
    slot: 'clock',
    metric: 'system.time.hhmm',
    platform: 'all',
  },
  {
    id: 'usage-widget',
    type: 'metric',
    enabled: true,
    slot: 'usage',
    metric: 'usage.primary.remaining_percent',
    platform: 'all',
  },
  {
    id: 'quick-actions-widget',
    type: 'action-list',
    enabled: true,
    slot: 'actions',
    actionIds: [
      'open-codexpet-docs',
      'copy-docs-link',
      'open-codex-path',
      'shell-placeholder-demo',
    ],
    platform: 'all',
  },
];

export const BUILT_IN_QUICK_ACTIONS: QuickActionSettings[] = [
  {
    id: 'open-codexpet-docs',
    name: 'Open Docs',
    icon: 'docs',
    kind: 'url',
    target: 'https://codexpet.xyz/docs',
    enabled: true,
    requireConfirm: false,
    platform: 'all',
  },
  {
    id: 'copy-docs-link',
    name: 'Copy Docs Link',
    icon: 'copy',
    kind: 'shortcut',
    target: 'copy:https://codexpet.xyz/docs',
    enabled: true,
    requireConfirm: false,
    platform: 'all',
  },
  {
    id: 'open-codex-path',
    name: 'Open Codex Path',
    icon: 'folder',
    kind: 'app',
    target: 'codex-home',
    enabled: true,
    requireConfirm: true,
    platform: 'all',
  },
  {
    id: 'shell-placeholder-demo',
    name: 'Shell Placeholder',
    icon: 'terminal',
    kind: 'shell-placeholder',
    target: 'echo disabled',
    enabled: false,
    requireConfirm: true,
    platform: 'all',
  },
];

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
  widgets: WidgetRuntimeConfig[];
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
    widgets: BUILT_IN_WIDGETS,
    managedPetIds: [],
    managedNestIds: [],
    quickActions: BUILT_IN_QUICK_ACTIONS,
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
  if (version === 2) {
    next = {
      ...next,
      schemaVersion: 3,
      widgets: Array.isArray(value.widgets) ? coerceWidgets(value.widgets) : BUILT_IN_WIDGETS,
      quickActions: Array.isArray(value.quickActions)
        ? mergeBuiltInQuickActions(value.quickActions.filter(isQuickAction))
        : BUILT_IN_QUICK_ACTIONS,
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
    widgets: Array.isArray(value.widgets) ? coerceWidgets(value.widgets) : BUILT_IN_WIDGETS,
    managedPetIds: stringArray(value.managedPetIds),
    managedNestIds: stringArray(value.managedNestIds),
    quickActions: Array.isArray(value.quickActions)
      ? mergeBuiltInQuickActions(value.quickActions.filter(isQuickAction))
      : BUILT_IN_QUICK_ACTIONS,
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
    isQuickActionType(value.kind) &&
    (value.platform === undefined || isActionPlatform(value.platform))
  );
}

function coerceWidgets(value: unknown[]): WidgetRuntimeConfig[] {
  const custom = value.filter(isWidgetRuntimeConfig);
  return mergeBuiltInWidgets(custom);
}

function mergeBuiltInWidgets(widgets: WidgetRuntimeConfig[]): WidgetRuntimeConfig[] {
  const byId = new Map(widgets.map((widget) => [widget.id, widget]));
  return BUILT_IN_WIDGETS.map((widget) => ({ ...widget, ...byId.get(widget.id) })).concat(
    widgets.filter((widget) => !BUILT_IN_WIDGETS.some((builtIn) => builtIn.id === widget.id)),
  );
}

function mergeBuiltInQuickActions(actions: QuickActionSettings[]): QuickActionSettings[] {
  const byId = new Map(actions.map((action) => [action.id, action]));
  return BUILT_IN_QUICK_ACTIONS.map((action) => ({ ...action, ...byId.get(action.id) })).concat(
    actions.filter((action) => !BUILT_IN_QUICK_ACTIONS.some((builtIn) => builtIn.id === action.id)),
  );
}

function isWidgetRuntimeConfig(value: unknown): value is WidgetRuntimeConfig {
  return (
    isRecord(value) &&
    typeof value.id === 'string' &&
    isWidgetType(value.type) &&
    typeof value.enabled === 'boolean' &&
    typeof value.slot === 'string' &&
    (value.metric === undefined || typeof value.metric === 'string') &&
    (value.actionIds === undefined ||
      (Array.isArray(value.actionIds) &&
        stringArray(value.actionIds).length === value.actionIds.length)) &&
    (value.platform === undefined || isActionPlatform(value.platform))
  );
}

export function validateWidgetActionConfig(
  widgets: unknown,
  quickActions: unknown,
  platform: ActionPlatform,
): WidgetActionValidationResult {
  const normalizedWidgets = Array.isArray(widgets) ? coerceWidgets(widgets) : BUILT_IN_WIDGETS;
  const normalizedActions = Array.isArray(quickActions)
    ? mergeBuiltInQuickActions(quickActions.filter(isQuickAction))
    : BUILT_IN_QUICK_ACTIONS;
  const actionIds = new Set(normalizedActions.map((action) => action.id));
  const errors: string[] = [];

  for (const widget of normalizedWidgets) {
    if (widget.type === 'action-list') {
      for (const actionId of widget.actionIds ?? []) {
        if (!actionIds.has(actionId))
          errors.push(`Widget ${widget.id} references missing action ${actionId}`);
      }
    }
  }

  for (const action of normalizedActions) {
    const targetError = validateActionTarget(action);
    if (targetError) errors.push(`${action.id}: ${targetError}`);
  }

  return {
    widgets: normalizedWidgets.filter((widget) => isPlatformSupported(widget.platform, platform)),
    quickActions: normalizedActions.map((action) => ({
      ...action,
      enabled: action.enabled && isPlatformSupported(action.platform, platform),
    })),
    errors,
  };
}

export function isPlatformSupported(
  targetPlatform: ActionPlatform | undefined,
  currentPlatform: ActionPlatform,
): boolean {
  return !targetPlatform || targetPlatform === 'all' || targetPlatform === currentPlatform;
}

export function validateActionTarget(action: QuickActionSettings): string | null {
  if (action.kind === 'shell-placeholder') return null;
  if (action.kind === 'url') {
    try {
      new URL(action.target);
      return action.target.startsWith('https://codexpet.xyz/') ||
        action.target.startsWith('http://localhost:')
        ? null
        : `URL target is not allowlisted: ${action.target}`;
    } catch {
      return 'URL target is invalid';
    }
  }
  if (action.kind === 'shortcut') {
    return action.target === 'copy:https://codexpet.xyz/docs' ||
      action.target === 'open-docs-placeholder'
      ? null
      : 'Shortcut target is not allowlisted';
  }
  return action.target === 'codex-home' ? null : 'App/path target is not allowlisted';
}

function isWidgetType(value: unknown): value is WidgetType {
  return value === 'metric' || value === 'action-list' || value === 'status';
}

function isQuickActionType(value: unknown): value is QuickActionType {
  return (
    value === 'url' || value === 'app' || value === 'shortcut' || value === 'shell-placeholder'
  );
}

function isActionPlatform(value: unknown): value is ActionPlatform {
  return value === 'macos' || value === 'windows' || value === 'linux' || value === 'all';
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
