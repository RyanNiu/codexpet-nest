import { useAppConfigStore } from '@/store/appConfigStore';
import { DebugPanel } from '@/components/debug/DebugPanel';

export function SettingsApp() {
  const { config, isLoading, error } = useAppConfigStore();

  return (
    <div
      style={{
        padding: 24,
        fontFamily: 'system-ui, sans-serif',
        maxWidth: 600,
        margin: '0 auto',
      }}
    >
      <h1>{config.appName} Settings</h1>
      {isLoading && <p>Loading configuration...</p>}
      {error && <p style={{ color: 'red' }}>Error: {error}</p>}
      {!isLoading && !error && (
        <div>
          <p>Version: {config.version}</p>
          <p>Platform: {config.platform}</p>
          <p>Data Directory: {config.dataDirectory}</p>
          <p>API URL: {config.apiBaseUrl}</p>
        </div>
      )}

      <DebugPanel />
    </div>
  );
}
