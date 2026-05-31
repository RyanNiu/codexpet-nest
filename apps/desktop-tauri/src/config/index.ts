/**
 * Unified application configuration for CodexPet Nest.
 * Values are sourced from Tauri's tauri.conf.json via Rust backend.
 *
 * Fallback values match the current Swift app for development safety.
 */

export interface AppConfig {
  /** Application display name */
  appName: string;
  /** Semantic version */
  version: string;
  /** Bundle identifier */
  bundleId: string;
  /** API base URL for marketplace / sync endpoints */
  apiBaseUrl: string;
  /** Platform-specific data directory (resolved by Rust) */
  dataDirectory: string;
  /** Whether app is running in debug/dev mode */
  isDebug: boolean;
  /** Current platform: 'macos' | 'windows' | 'linux' */
  platform: string;
}

export const FALLBACK_CONFIG: AppConfig = {
  appName: 'CodexPet Nest',
  version: '0.1.12',
  bundleId: 'xyz.codexpet.nest',
  apiBaseUrl: 'https://codexpet.xyz',
  dataDirectory: '',
  isDebug: import.meta.env.DEV,
  platform: 'macos',
};
