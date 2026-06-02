import { useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { builtInNestFixtures } from '@codexpet/renderer/fixtures/nests';
import type { OverlayMode } from '@codexpet/core';
import { useAppConfigStore } from '@/store/appConfigStore';
import { useSettingsStore } from '@/store/settingsStore';
import { DebugPanel } from '@/components/debug/DebugPanel';

const overlayModeOptions: OverlayMode[] = ['follow-codex', 'standalone-fixed'];

export function SettingsApp() {
  const { config, isLoading, error } = useAppConfigStore();
  const {
    settings,
    isLoading: settingsLoading,
    isSaving,
    error: settingsError,
    update,
  } = useSettingsStore();
  const [overlayVisible, setOverlayVisible] = useState<boolean | null>(null);
  const [overlayControlError, setOverlayControlError] = useState<string | null>(null);

  const activeNestId = settings.activeNestId ?? builtInNestFixtures[0]?.id ?? '';

  useEffect(() => {
    invoke<boolean>('is_overlay_visible')
      .then((visible) => {
        setOverlayVisible(visible);
        setOverlayControlError(null);
      })
      .catch((invokeError) => setOverlayControlError(String(invokeError)));
  }, []);

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

  return (
    <div
      style={{
        minHeight: '100vh',
        padding: 32,
        fontFamily: 'system-ui, sans-serif',
        maxWidth: 840,
        margin: '0 auto',
        color: '#18202f',
        background: 'linear-gradient(180deg, #f8fafc 0%, #eef4ff 100%)',
      }}
    >
      <header style={{ marginBottom: 24 }}>
        <p style={{ margin: '0 0 6px', color: '#64748b', fontSize: 13, fontWeight: 700 }}>
          Local Management
        </p>
        <h1 style={{ margin: 0, fontSize: 32 }}>{config.appName} Settings</h1>
        <p style={{ margin: '8px 0 0', color: '#64748b' }}>
          Manage the local nest and overlay behavior stored on this device.
        </p>
      </header>

      {(isLoading || settingsLoading) && <p>Loading configuration...</p>}
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
      {overlayControlError && (
        <p role="alert" style={{ color: '#b91c1c' }}>
          Overlay control error: {overlayControlError}
        </p>
      )}

      {!isLoading && !settingsLoading && !error && (
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
                  Control whether the nest is visible and how it behaves above Codex.
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
          </section>

          <section style={cardStyle}>
            <h2 style={sectionTitleStyle}>Nest Runtime</h2>
            <div style={fieldGridStyle}>
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
                      {mode}
                    </option>
                  ))}
                </select>
              </label>
              <label style={fieldStyle}>
                <span style={labelStyle}>Built-in nest</span>
                <select
                  aria-label="Built-in nest"
                  value={activeNestId}
                  onChange={(event) =>
                    update({ activeNestId: event.currentTarget.value }).catch(() => undefined)
                  }
                  style={selectStyle}
                >
                  {builtInNestFixtures.map((fixture) => (
                    <option key={fixture.id} value={fixture.id}>
                      {fixture.packageManifest.name}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <p style={{ ...descriptionStyle, marginTop: 12 }}>
              {isSaving
                ? 'Saving settings...'
                : `Saved locally to ${config.dataDirectory}/settings.json`}
            </p>
          </section>

          <section style={cardStyle}>
            <h2 style={sectionTitleStyle}>App Info</h2>
            <dl style={{ display: 'grid', gap: 6, margin: 0, color: '#475569', fontSize: 13 }}>
              <div>Version: {config.version}</div>
              <div>Platform: {config.platform}</div>
              <div>Data Directory: {config.dataDirectory}</div>
              <div>API URL: {config.apiBaseUrl}</div>
            </dl>
          </section>

          <details style={{ ...cardStyle, padding: 0 }}>
            <summary style={{ padding: 18, cursor: 'pointer', fontWeight: 800 }}>
              Debug Panel
            </summary>
            <div style={{ padding: '0 18px 18px' }}>
              <DebugPanel />
            </div>
          </details>
        </main>
      )}
    </div>
  );
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
