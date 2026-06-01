import { useEffect, useState } from 'react';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { ConfigProvider } from '@/components/shared/ConfigProvider';
import { OverlayApp } from '@/components/overlay/OverlayApp';
import { SettingsApp } from '@/components/settings/SettingsApp';

/**
 * Root component. Each Tauri window renders this same React bundle.
 * The window label determines which sub-component to render.
 *
 * Resolution strategy (in order):
 *   1. Tauri window label API (`getCurrentWebviewWindow().label`) — most reliable
 *   2. URL query param (`?label=...`) passed from Rust when creating the window
 *   3. Fallback to "main" (settings window)
 *
 * Window labels:
 *   - "main"      = settings window (normal window)
 *   - "overlay"   = transparent overlay window
 */
export function App() {
  const [windowLabel, setWindowLabel] = useState<string | null>(null);

  useEffect(() => {
    // Resolve the window label using the Tauri API first, then fall back
    // to the URL query param, then to "main".
    try {
      const currentWindow = getCurrentWebviewWindow();
      setWindowLabel(currentWindow.label);
    } catch {
      // Not running inside Tauri (e.g. test environment) — try URL query param
      const params = new URLSearchParams(window.location.search);
      const label = params.get('label');
      setWindowLabel(label ?? 'main');
    }
  }, []);

  if (windowLabel === null) {
    // Still resolving — render nothing (or a minimal loader).
    // The ConfigProvider will fetch config asynchronously anyway.
    return null;
  }

  return (
    <ConfigProvider>{windowLabel === 'overlay' ? <OverlayApp /> : <SettingsApp />}</ConfigProvider>
  );
}
