import { useCallback, useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { validateWidgetActionConfig } from '@codexpet/core';
import type { ActionPlatform, OverlayMode, QuickActionSettings } from '@codexpet/core';
import { useAppConfigStore } from '@/store/appConfigStore';
import {
  getEnabledNestEntries,
  getNestEntries,
  resolveActiveNestEntry,
  useRegistryStore,
} from '@/store/registryStore';
import { useSettingsStore } from '@/store/settingsStore';
import { DebugPanel } from '@/components/debug/DebugPanel';

const overlayModeOptions: OverlayMode[] = ['follow-codex', 'standalone-fixed'];
const overlayModeLabels: Record<OverlayMode, string> = {
  'follow-codex': 'Follow Codex',
  'standalone-fixed': 'Standalone fixed/manual',
  'standalone-roam': 'Standalone roam',
};

interface OverlayFollowDiagnostics {
  runtimeMode: string;
  lastCodexStateReadAt: string | null;
  lastTargetPosition: string | null;
  followLoopActive: boolean;
  lastMoveFailure: string | null;
}

interface LocalSnapshotExportResult {
  exportPath: string;
  exportedAt: string;
}

const FOLLOW_DIAGNOSTICS_KEY = 'codexpet.overlay.followDiagnostics';

export function SettingsApp() {
  const { config, isLoading, error } = useAppConfigStore();
  const {
    registry,
    isLoading: registryLoading,
    isSaving: registrySaving,
    error: registryError,
    load: loadRegistry,
    importPackage,
  } = useRegistryStore();
  const {
    settings,
    isLoading: settingsLoading,
    isSaving,
    error: settingsError,
    load: loadSettings,
    update,
  } = useSettingsStore();
  const [overlayVisible, setOverlayVisible] = useState<boolean | null>(null);
  const [overlayControlError, setOverlayControlError] = useState<string | null>(null);
  const [importPath, setImportPath] = useState('');
  const [importError, setImportError] = useState<string | null>(null);
  const [snapshotExportPath, setSnapshotExportPath] = useState('');
  const [snapshotImportPath, setSnapshotImportPath] = useState('');
  const [snapshotStatus, setSnapshotStatus] = useState<string | null>(null);
  const [snapshotError, setSnapshotError] = useState<string | null>(null);
  const [actionCapabilities, setActionCapabilities] = useState<string[]>([]);
  const [followDiagnostics, setFollowDiagnostics] = useState<OverlayFollowDiagnostics | null>(null);

  const allNestEntries = getNestEntries(registry);
  const nestEntries = getEnabledNestEntries(registry);
  const { entry: activeNestEntry, fallback: nestFallback } = resolveActiveNestEntry(
    registry,
    settings.activeNestId,
  );
  const activeNestId = activeNestEntry?.id ?? '';
  const actionPlatform = toActionPlatform(config.platform);
  const widgetActionConfig = validateWidgetActionConfig(
    settings.widgets,
    settings.quickActions,
    actionPlatform,
  );

  const refreshFollowDiagnostics = useCallback(() => {
    const raw = window.localStorage.getItem(FOLLOW_DIAGNOSTICS_KEY);
    if (!raw) return;
    try {
      setFollowDiagnostics(JSON.parse(raw) as OverlayFollowDiagnostics);
    } catch {
      setFollowDiagnostics(null);
    }
  }, []);

  useEffect(() => {
    invoke<boolean>('is_overlay_visible')
      .then((visible) => {
        setOverlayVisible(visible);
        setOverlayControlError(null);
      })
      .catch((invokeError) => setOverlayControlError(String(invokeError)));
  }, []);

  useEffect(() => {
    invoke<{ supportedActionTypes: string[] }>('get_action_capabilities')
      .then((capabilities) => setActionCapabilities(capabilities.supportedActionTypes))
      .catch(() => setActionCapabilities([]));
  }, []);

  useEffect(() => {
    refreshFollowDiagnostics();
    const interval = window.setInterval(refreshFollowDiagnostics, 1_000);
    return () => window.clearInterval(interval);
  }, [refreshFollowDiagnostics]);

  const showOverlay = () => {
    invoke('show_overlay')
      .then(() => {
        setOverlayVisible(true);
        setOverlayControlError(null);
      })
      .catch((invokeError) => setOverlayControlError(String(invokeError)));
  };

  const hideOverlay = () => {
    invoke('hide_overlay')
      .then(() => {
        setOverlayVisible(false);
        setOverlayControlError(null);
      })
      .catch((invokeError) => setOverlayControlError(String(invokeError)));
  };

  const setClickThrough = async (enabled: boolean) => {
    const previous = settings.clickThrough;
    let nativeApplied = false;
    setOverlayControlError(null);
    try {
      await invoke('set_overlay_click_through', { enabled });
      nativeApplied = true;
      await update({ clickThrough: enabled });
    } catch (transactionError) {
      if (nativeApplied) {
        await invoke('set_overlay_click_through', { enabled: previous }).catch(() => undefined);
      }
      setOverlayControlError(String(transactionError));
    }
  };

  const importLocalPackage = async () => {
    const trimmed = importPath.trim();
    if (!trimmed) return;
    setImportError(null);
    try {
      await importPackage(trimmed);
      setImportPath('');
    } catch (importFailure) {
      setImportError(String(importFailure));
    }
  };

  const exportLocalSnapshot = async () => {
    const trimmed = snapshotExportPath.trim();
    if (!trimmed) return;
    setSnapshotError(null);
    setSnapshotStatus(null);
    try {
      const result = await invoke<LocalSnapshotExportResult>('export_local_snapshot', {
        exportPath: trimmed,
        settings,
        registry,
      });
      setSnapshotStatus(`Exported local snapshot to ${result.exportPath}`);
    } catch (exportFailure) {
      setSnapshotError(String(exportFailure));
    }
  };

  const importLocalSnapshot = async () => {
    const trimmed = snapshotImportPath.trim();
    if (!trimmed) return;
    setSnapshotError(null);
    setSnapshotStatus(null);
    try {
      await invoke('import_local_snapshot', { importPath: trimmed });
      await Promise.all([loadSettings(), loadRegistry()]);
      setSnapshotImportPath('');
      setSnapshotStatus('Imported local snapshot. Settings and registry were reloaded locally.');
    } catch (importFailure) {
      setSnapshotError(String(importFailure));
    }
  };

  const setActionEnabled = (actionId: string, enabled: boolean) => {
    const quickActions = settings.quickActions.map((action) =>
      action.id === actionId ? { ...action, enabled } : action,
    );
    update({ quickActions }).catch(() => undefined);
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        padding: 32,
        fontFamily: 'system-ui, sans-serif',
        maxWidth: 980,
        margin: '0 auto',
        color: '#18202f',
        background: 'linear-gradient(180deg, #f8fafc 0%, #eef4ff 100%)',
      }}
    >
      <header style={{ marginBottom: 24 }}>
        <p style={{ margin: '0 0 6px', color: '#64748b', fontSize: 13, fontWeight: 700 }}>
          Desktop App Settings
        </p>
        <h1 style={{ margin: 0, fontSize: 32 }}>{config.appName} Settings</h1>
        <p style={{ margin: '8px 0 0', color: '#64748b' }}>
          Manage the overlay, local nests, widgets, and diagnostics stored on this device.
        </p>
      </header>

      {(isLoading || settingsLoading || registryLoading) && <p>Loading configuration...</p>}
      {error && (
        <p role="alert" style={{ color: '#b91c1c' }}>
          App config error: {error}
        </p>
      )}
      {settingsError && (
        <p role="alert" style={{ color: '#b91c1c' }}>
          Settings error: {settingsError}
        </p>
      )}
      {registryError && (
        <p role="alert" style={{ color: '#b91c1c' }}>
          Registry error: {registryError}
        </p>
      )}
      {overlayControlError && (
        <p role="alert" style={{ color: '#b91c1c' }}>
          Overlay control error: {overlayControlError}
        </p>
      )}

      {!isLoading && !settingsLoading && !registryLoading && !error && (
        <main
          style={{
            display: 'grid',
            gap: 16,
          }}
        >
          <section style={cardStyle}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
              <div>
                <h2 style={sectionTitleStyle}>Overlay</h2>
                <p style={descriptionStyle}>
                  Control whether the nest is visible, interactive, and linked to Codex.
                </p>
              </div>
              <span style={{ ...pillStyle, color: overlayVisible ? '#047857' : '#b91c1c' }}>
                {overlayVisible === null ? 'Unknown' : overlayVisible ? 'Visible' : 'Hidden'}
              </span>
            </div>
            <div style={buttonRowStyle}>
              <button type="button" style={primaryButtonStyle} onClick={showOverlay}>
                Show Overlay
              </button>
              <button type="button" style={secondaryButtonStyle} onClick={hideOverlay}>
                Hide Overlay
              </button>
            </div>
            <div style={{ ...fieldGridStyle, marginTop: 16 }}>
              <label style={fieldStyle}>
                <span style={labelStyle}>Overlay mode</span>
                <select
                  aria-label="Overlay mode"
                  value={settings.overlayMode}
                  onChange={(event) =>
                    update({ overlayMode: event.currentTarget.value as OverlayMode }).catch(
                      () => undefined,
                    )
                  }
                  style={selectStyle}
                >
                  {overlayModeOptions.map((mode) => (
                    <option key={mode} value={mode}>
                      {overlayModeLabels[mode]}
                    </option>
                  ))}
                </select>
              </label>
              <div style={modeHintStyle}>
                {settings.overlayMode === 'follow-codex'
                  ? 'Nest follows the Codex pet when Codex state is available. If it is not available, the overlay holds its current or saved position.'
                  : 'Nest stays at the saved standalone position. Drag the overlay when click-through is off to update the saved position.'}
              </div>
            </div>
            <label style={toggleRowStyle}>
              <span>
                <strong>Click-through</strong>
                <span style={descriptionStyle}>
                  {' '}
                  Allow mouse events to pass through the overlay.
                </span>
              </span>
              <input
                type="checkbox"
                checked={settings.clickThrough}
                onChange={(event) => setClickThrough(event.currentTarget.checked)}
              />
            </label>
            {settings.clickThrough && (
              <p style={{ ...descriptionStyle, color: '#b45309', marginTop: 10 }}>
                Click-through is on, so overlay buttons are visually muted and cannot be clicked
                until this is turned off.
              </p>
            )}
          </section>

          <section style={cardStyle}>
            <h2 style={sectionTitleStyle}>Follow Status</h2>
            <p style={{ ...descriptionStyle, marginBottom: 12 }}>
              Runtime diagnostics stay here instead of inside the overlay.
            </p>
            <div style={fieldGridStyle}>
              <div style={statusTileStyle}>
                <span style={labelStyle}>Mode</span>
                <strong>{overlayModeLabels[settings.overlayMode]}</strong>
              </div>
              <div style={statusTileStyle}>
                <span style={labelStyle}>Follow loop</span>
                <strong>{followDiagnostics?.followLoopActive ? 'Active' : 'Not active'}</strong>
              </div>
              <div style={statusTileStyle}>
                <span style={labelStyle}>Last Codex read</span>
                <strong>{followDiagnostics?.lastCodexStateReadAt ?? 'Not recorded yet'}</strong>
              </div>
            </div>
            {followDiagnostics?.lastMoveFailure && (
              <p style={{ ...descriptionStyle, color: '#b45309', marginTop: 12 }}>
                Codex follow is unavailable right now. The overlay will keep its current or saved
                position. Open Development Diagnostics for technical details.
              </p>
            )}
            <p style={{ ...descriptionStyle, marginTop: 12 }}>
              {isSaving
                ? 'Saving settings...'
                : `Saved locally to ${config.dataDirectory}/settings.json`}
            </p>
          </section>

          <section style={cardStyle}>
            <h2 style={sectionTitleStyle}>Widgets / Actions</h2>
            <p style={{ ...descriptionStyle, marginBottom: 12 }}>
              Built-in runtime widgets and safe quick actions. Shell placeholders remain disabled.
            </p>
            {widgetActionConfig.errors.length > 0 && (
              <p role="alert" style={{ color: '#b91c1c', margin: '0 0 12px' }}>
                Widget/action config error: {widgetActionConfig.errors.join('; ')}
              </p>
            )}
            <div style={{ display: 'grid', gap: 8, marginBottom: 14 }}>
              {settings.widgets.map((widget) => (
                <div key={widget.id} style={actionRowStyle}>
                  <span style={{ fontWeight: 800 }}>{widget.id}</span>
                  <span style={descriptionStyle}>{widget.type}</span>
                  <span style={descriptionStyle}>slot: {widget.slot}</span>
                  <span style={{ ...pillStyle, color: widget.enabled ? '#047857' : '#b91c1c' }}>
                    {widget.enabled ? 'enabled' : 'disabled'}
                  </span>
                </div>
              ))}
            </div>
            <div style={{ display: 'grid', gap: 8 }}>
              {settings.quickActions.map((action) => (
                <ActionSettingsRow
                  key={action.id}
                  action={action}
                  platform={actionPlatform}
                  supported={actionCapabilities.includes(action.kind)}
                  onToggle={setActionEnabled}
                />
              ))}
            </div>
          </section>

          <section style={cardStyle}>
            <h2 style={sectionTitleStyle}>Local Packages / Nests</h2>
            <p style={{ ...descriptionStyle, marginBottom: 12 }}>
              Select the active nest from the local package registry.
            </p>
            <div style={{ display: 'flex', gap: 8, marginBottom: 14 }}>
              <input
                aria-label="Local package directory"
                value={importPath}
                onChange={(event) => setImportPath(event.currentTarget.value)}
                placeholder="/path/to/local/nest-package"
                style={{ ...selectStyle, flex: 1 }}
              />
              <button
                type="button"
                style={primaryButtonStyle}
                onClick={() => void importLocalPackage()}
                disabled={registrySaving || importPath.trim().length === 0}
              >
                {registrySaving ? 'Importing...' : 'Import'}
              </button>
            </div>
            {importError && (
              <p role="alert" style={{ color: '#b91c1c', margin: '0 0 12px' }}>
                Import error: {importError}
              </p>
            )}
            <label style={{ ...fieldStyle, marginBottom: 12 }}>
              <span style={labelStyle}>Active nest</span>
              <select
                aria-label="Active nest"
                value={activeNestId}
                onChange={(event) =>
                  update({ activeNestId: event.currentTarget.value }).catch(() => undefined)
                }
                style={selectStyle}
              >
                {nestEntries.map((entry) => (
                  <option key={entry.id} value={entry.id}>
                    {entry.name}
                  </option>
                ))}
              </select>
            </label>
            {nestFallback && settings.activeNestId && (
              <p style={{ ...descriptionStyle, color: '#b45309', marginBottom: 10 }}>
                Saved nest `{settings.activeNestId}` is unavailable. Using `{activeNestId}`.
              </p>
            )}
            <div style={{ display: 'grid', gap: 8 }}>
              {allNestEntries.map((entry) => (
                <button
                  key={entry.id}
                  type="button"
                  onClick={() => {
                    if (entry.enabled) update({ activeNestId: entry.id }).catch(() => undefined);
                  }}
                  disabled={!entry.enabled}
                  style={{
                    ...packageRowStyle,
                    borderColor: activeNestId === entry.id ? '#2563eb' : '#e2e8f0',
                    background: activeNestId === entry.id ? '#eff6ff' : '#ffffff',
                    cursor: entry.enabled ? 'pointer' : 'not-allowed',
                    opacity: entry.enabled ? 1 : 0.68,
                  }}
                >
                  <span style={{ fontWeight: 800 }}>{entry.name}</span>
                  <span style={descriptionStyle}>v{entry.version}</span>
                  <span style={descriptionStyle}>{entry.type}</span>
                  <span style={{ ...pillStyle, color: entry.enabled ? '#047857' : '#b91c1c' }}>
                    {entry.enabled ? 'enabled' : 'disabled'}
                  </span>
                </button>
              ))}
            </div>
          </section>

          <section style={cardStyle}>
            <h2 style={sectionTitleStyle}>Local Snapshot</h2>
            <p style={{ ...descriptionStyle, marginBottom: 12 }}>
              Export or import this device&apos;s settings and local registry metadata. Package
              asset folders are not copied, so imported local package paths must still exist on this
              device.
            </p>
            <div style={{ display: 'grid', gap: 10 }}>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  aria-label="Local snapshot export path"
                  value={snapshotExportPath}
                  onChange={(event) => setSnapshotExportPath(event.currentTarget.value)}
                  placeholder={`${config.dataDirectory}/codexpet-nest-snapshot.json`}
                  style={{ ...selectStyle, flex: 1 }}
                />
                <button
                  type="button"
                  style={secondaryButtonStyle}
                  onClick={() => void exportLocalSnapshot()}
                  disabled={snapshotExportPath.trim().length === 0}
                >
                  Export Snapshot
                </button>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  aria-label="Local snapshot import path"
                  value={snapshotImportPath}
                  onChange={(event) => setSnapshotImportPath(event.currentTarget.value)}
                  placeholder="/path/to/codexpet-nest-snapshot.json"
                  style={{ ...selectStyle, flex: 1 }}
                />
                <button
                  type="button"
                  style={secondaryButtonStyle}
                  onClick={() => void importLocalSnapshot()}
                  disabled={snapshotImportPath.trim().length === 0}
                >
                  Import Snapshot
                </button>
              </div>
            </div>
            {snapshotStatus && (
              <p role="status" style={{ color: '#047857', margin: '12px 0 0' }}>
                {snapshotStatus}
              </p>
            )}
            {snapshotError && (
              <p role="alert" style={{ color: '#b91c1c', margin: '12px 0 0' }}>
                Snapshot error: {snapshotError}
              </p>
            )}
          </section>

          <section style={cardStyle}>
            <h2 style={sectionTitleStyle}>App Info</h2>
            <dl style={{ display: 'grid', gap: 6, margin: 0, color: '#475569', fontSize: 13 }}>
              <div>Version: {config.version}</div>
              <div>Platform: {config.platform}</div>
              <div>Data Directory: {config.dataDirectory}</div>
            </dl>
          </section>

          <details style={{ ...cardStyle, padding: 0 }}>
            <summary style={{ padding: 18, cursor: 'pointer', fontWeight: 800 }}>
              Development Diagnostics
            </summary>
            <p style={{ ...descriptionStyle, padding: '0 18px 12px' }}>
              Developer-only tools for overlay windows, Codex state, screens, drag diagnostics, and
              release verification. These controls do not affect normal settings rendering.
            </p>
            <div style={{ padding: '0 18px 18px' }}>
              <DebugPanel />
            </div>
          </details>
        </main>
      )}
    </div>
  );
}

function ActionSettingsRow({
  action,
  platform,
  supported,
  onToggle,
}: {
  action: QuickActionSettings;
  platform: ActionPlatform;
  supported: boolean;
  onToggle: (actionId: string, enabled: boolean) => void;
}) {
  const platformSupported =
    !action.platform || action.platform === 'all' || action.platform === platform;
  const disabledByRuntime = action.kind === 'shell-placeholder' || !platformSupported || !supported;
  const status = disabledByRuntime ? 'disabled' : action.enabled ? 'enabled' : 'off';

  return (
    <label style={{ ...actionRowStyle, opacity: disabledByRuntime ? 0.68 : 1 }}>
      <input
        type="checkbox"
        aria-label={`Enable ${action.name}`}
        checked={action.enabled && !disabledByRuntime}
        disabled={disabledByRuntime}
        onChange={(event) => onToggle(action.id, event.currentTarget.checked)}
      />
      <span style={{ fontWeight: 800 }}>{action.name}</span>
      <span style={descriptionStyle}>{action.kind}</span>
      <span style={descriptionStyle}>platform: {action.platform ?? 'all'}</span>
      <span style={descriptionStyle}>confirm: {String(action.requireConfirm)}</span>
      <span style={{ ...pillStyle, color: status === 'enabled' ? '#047857' : '#b91c1c' }}>
        {status}
      </span>
    </label>
  );
}

function toActionPlatform(platform: string): ActionPlatform {
  if (platform === 'macos' || platform === 'windows' || platform === 'linux') return platform;
  return 'all';
}

const cardStyle: React.CSSProperties = {
  padding: 18,
  borderRadius: 16,
  background: 'rgba(255,255,255,0.92)',
  border: '1px solid rgba(148,163,184,0.25)',
  boxShadow: '0 16px 40px rgba(15,23,42,0.08)',
};

const sectionTitleStyle: React.CSSProperties = { margin: '0 0 6px', fontSize: 18 };
const descriptionStyle: React.CSSProperties = { margin: 0, color: '#64748b', fontSize: 13 };
const buttonRowStyle: React.CSSProperties = { display: 'flex', gap: 10, marginTop: 14 };
const primaryButtonStyle: React.CSSProperties = {
  border: 0,
  borderRadius: 10,
  padding: '9px 14px',
  background: '#2563eb',
  color: '#fff',
  fontWeight: 800,
  cursor: 'pointer',
};
const secondaryButtonStyle: React.CSSProperties = {
  ...primaryButtonStyle,
  background: '#e2e8f0',
  color: '#0f172a',
};
const toggleRowStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 16,
  marginTop: 16,
};
const fieldGridStyle: React.CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
  gap: 14,
};
const fieldStyle: React.CSSProperties = { display: 'grid', gap: 6 };
const labelStyle: React.CSSProperties = { fontSize: 12, fontWeight: 800, color: '#475569' };
const modeHintStyle: React.CSSProperties = {
  ...descriptionStyle,
  padding: 12,
  borderRadius: 12,
  background: '#f8fafc',
  border: '1px solid #e2e8f0',
};
const statusTileStyle: React.CSSProperties = {
  display: 'grid',
  gap: 4,
  padding: 12,
  borderRadius: 12,
  background: '#f8fafc',
  border: '1px solid #e2e8f0',
  minWidth: 0,
};
const selectStyle: React.CSSProperties = {
  border: '1px solid #cbd5e1',
  borderRadius: 10,
  padding: '9px 10px',
  background: '#fff',
};
const pillStyle: React.CSSProperties = {
  alignSelf: 'flex-start',
  borderRadius: 999,
  background: '#f1f5f9',
  padding: '5px 10px',
  fontSize: 12,
  fontWeight: 800,
};
const packageRowStyle: React.CSSProperties = {
  width: '100%',
  display: 'grid',
  gridTemplateColumns: '1fr auto auto auto',
  alignItems: 'center',
  gap: 10,
  border: '1px solid #e2e8f0',
  borderRadius: 12,
  padding: '10px 12px',
  color: '#18202f',
  textAlign: 'left',
  cursor: 'pointer',
};
const actionRowStyle: React.CSSProperties = {
  width: '100%',
  display: 'grid',
  gridTemplateColumns: 'auto 1fr auto auto auto auto',
  alignItems: 'center',
  gap: 10,
  border: '1px solid #e2e8f0',
  borderRadius: 12,
  padding: '10px 12px',
  color: '#18202f',
  textAlign: 'left',
};
