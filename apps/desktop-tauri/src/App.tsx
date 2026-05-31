import { ConfigProvider } from '@/components/shared/ConfigProvider';
import { OverlayApp } from '@/components/overlay/OverlayApp';
import { SettingsApp } from '@/components/settings/SettingsApp';

/**
 * Root component. Each Tauri window renders this same React bundle.
 * The window label (determined by which HTML page or query param is loaded)
 * determines which sub-component to render.
 *
 * Window labels defined in Tauri config and Rust code:
 *   - "main"      = settings window (normal window)
 *   - "overlay"   = transparent overlay window
 */
export function App() {
  // In Tauri, the current window label is accessible via @tauri-apps/api.
  // For simplicity at bootstrap, we detect the label from the URL query param
  // that Rust passes when creating each window.
  const params = new URLSearchParams(window.location.search);
  const windowLabel = params.get('label') ?? 'main';

  return (
    <ConfigProvider>{windowLabel === 'overlay' ? <OverlayApp /> : <SettingsApp />}</ConfigProvider>
  );
}
