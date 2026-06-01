import '@testing-library/jest-dom/vitest';
import { beforeEach, vi } from 'vitest';
import { useAppConfigStore } from '@/store/appConfigStore';
import { FALLBACK_CONFIG } from '@/config';
import { useDebugStore } from '@/store/debugStore';

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
  invoke: vi.fn(),
}));

beforeEach(async () => {
  useAppConfigStore.setState({ config: FALLBACK_CONFIG, isLoading: true, error: null });
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
      case 'get_codex_state':
        return Promise.resolve(codexState);
      case 'get_screen_list':
        return Promise.resolve([]);
      case 'is_overlay_visible':
        return Promise.resolve(true);
      case 'convert_position':
        return Promise.resolve({ x: 0, y: 0, scale_factor: 1, display_index: 0 });
      case 'show_overlay':
      case 'hide_overlay':
      case 'set_overlay_click_through':
        return Promise.resolve(undefined);
      default:
        return Promise.reject(new Error(`Unhandled invoke command: ${String(command)}`));
    }
  });
});
