import '@testing-library/jest-dom/vitest';
import { beforeEach, vi } from 'vitest';
import { useAppConfigStore } from '@/store/appConfigStore';
import { FALLBACK_CONFIG } from '@/config';
import { useDebugStore } from '@/store/debugStore';
import { builtInNestRegistryEntries, useRegistryStore } from '@/store/registryStore';
import { useSettingsStore } from '@/store/settingsStore';
import { createDefaultPackageRegistry, createDefaultSettings } from '@codexpet/core';

Object.defineProperty(HTMLElement.prototype, 'setPointerCapture', {
  configurable: true,
  value: vi.fn(),
});

Object.defineProperty(HTMLElement.prototype, 'releasePointerCapture', {
  configurable: true,
  value: vi.fn(),
});

Object.defineProperty(HTMLElement.prototype, 'hasPointerCapture', {
  configurable: true,
  value: vi.fn(() => true),
});

const fallbackConfig = {
  appName: 'CodexPet Nest',
  version: '0.1.12',
  platform: 'test',
  isDebug: true,
  apiBaseUrl: 'http://localhost:3000',
  dataDirectory: '/tmp/codexpet-nest-test',
  bundleId: 'com.codexpet.nest.test',
};

const codexState = {
  avatar_overlay_open: true,
  overlay_bounds: null,
  state_available: true,
  diagnostic: 'test',
  codex_home: '/tmp/.codex',
};

vi.mock('@tauri-apps/api/core', () => ({
  convertFileSrc: vi.fn((path: string) => `asset://${path}`),
  invoke: vi.fn(),
}));

vi.mock('@tauri-apps/api/webviewWindow', () => ({
  getCurrentWebviewWindow: vi.fn(() => ({
    startDragging: vi.fn(() => Promise.resolve()),
  })),
}));

beforeEach(async () => {
  window.localStorage.clear();
  const fallbackSettings = createDefaultSettings();
  const fallbackRegistry = {
    ...createDefaultPackageRegistry(),
    packages: builtInNestRegistryEntries,
  };
  useAppConfigStore.setState({ config: FALLBACK_CONFIG, isLoading: true, error: null });
  useRegistryStore.setState({
    registry: fallbackRegistry,
    isLoading: true,
    isSaving: false,
    error: null,
  });
  useSettingsStore.setState({
    settings: fallbackSettings,
    isLoading: true,
    isSaving: false,
    error: null,
  });
  useDebugStore.setState({
    codexState: null,
    codexStateLoading: false,
    codexStateError: null,
    screens: [],
    screensLoading: false,
    screensError: null,
    convertedPosition: null,
    clickThrough: false,
  });

  const { invoke } = await import('@tauri-apps/api/core');
  vi.mocked(invoke).mockReset();
  vi.mocked(invoke).mockImplementation((command) => {
    switch (command) {
      case 'get_app_config':
        return Promise.resolve(fallbackConfig);
      case 'get_action_capabilities':
      case 'list_supported_actions':
        return Promise.resolve({
          platform: 'macos',
          supportedActionTypes: ['url', 'app', 'shortcut'],
          disabledActionTypes: ['shell-placeholder'],
          allowlistedUrlPrefixes: ['https://codexpet.xyz/', 'http://localhost:'],
          allowlistedAppTargets: ['codex-home'],
          shellExecutionEnabled: false,
        });
      case 'execute_quick_action':
        return Promise.resolve({
          id: 'test-action',
          status: 'mocked',
          message: 'Action completed in test',
        });
      case 'load_local_settings':
        return Promise.resolve(fallbackSettings);
      case 'save_local_settings':
        return Promise.resolve(undefined);
      case 'load_local_registry':
        return Promise.resolve(fallbackRegistry);
      case 'save_local_registry':
        return Promise.resolve(undefined);
      case 'import_local_package':
        return Promise.resolve(fallbackRegistry);
      case 'export_local_snapshot':
        return Promise.resolve({
          schemaVersion: 1,
          exportPath: '/tmp/codexpet-nest-snapshot.json',
          exportedAt: 'unix:0',
        });
      case 'import_local_snapshot':
        return Promise.resolve({
          settings: fallbackSettings,
          registry: fallbackRegistry,
          importedAt: 'unix:0',
        });
      case 'load_local_nest_package':
        return Promise.resolve({ nestLayout: {}, missingAssets: [] });
      case 'get_codex_state':
        return Promise.resolve(codexState);
      case 'get_screen_list':
        return Promise.resolve([]);
      case 'is_overlay_visible':
        return Promise.resolve(true);
      case 'get_overlay_position':
        return Promise.resolve({ x: 100, y: 100 });
      case 'convert_position':
        return Promise.resolve({ x: 0, y: 0, scale_factor: 1, display_index: 0 });
      case 'move_overlay_to_clamped':
        return Promise.resolve({ x: 100, y: 100, display_index: 0 });
      case 'show_overlay':
      case 'hide_overlay':
      case 'reset_overlay_position':
      case 'resize_overlay_debug':
      case 'set_overlay_position':
      case 'move_overlay_by':
      case 'set_overlay_click_through':
        return Promise.resolve(undefined);
      default:
        return Promise.reject(new Error(`Unhandled invoke command: ${String(command)}`));
    }
  });
});
