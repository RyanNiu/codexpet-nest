export interface SyncRecord<T = unknown> {
  id: string;
  collection: 'settings' | 'widgetConfigs' | 'installedPackages' | 'selectedNest' | 'quickActions';
  value: T;
  updatedAt: string;
  version: number;
  deleted: boolean;
  deviceId: string;
}

export interface SyncDevice {
  id: string;
  platform: 'macos' | 'windows' | 'linux' | 'unknown';
  appVersion: string;
  lastSeenAt: string;
}
