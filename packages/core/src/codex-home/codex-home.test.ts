import { describe, expect, it } from 'vitest';
import { resolveCodexHome } from './index';

describe('resolveCodexHome', () => {
  it('uses CODEX_HOME before default paths', () => {
    const result = resolveCodexHome({
      platform: 'macos',
      homeDir: '/Users/test',
      env: { CODEX_HOME: '~/custom-codex' },
    });

    expect(result.ok).toBe(true);
    expect(result.source).toBe('CODEX_HOME');
    expect(result.path).toBe('/Users/test/custom-codex');
  });

  it('uses default .codex path on macOS and Linux', () => {
    expect(resolveCodexHome({ platform: 'macos', homeDir: '/Users/test', env: {} }).path).toBe(
      '/Users/test/.codex',
    );
    expect(resolveCodexHome({ platform: 'linux', homeDir: '/home/test', env: {} }).path).toBe(
      '/home/test/.codex',
    );
  });

  it('uses default .codex path on Windows', () => {
    const result = resolveCodexHome({ platform: 'windows', homeDir: 'C:\\Users\\test', env: {} });

    expect(result.ok).toBe(true);
    expect(result.path).toBe('C:\\Users\\test\\.codex');
  });

  it('rejects protected paths', () => {
    expect(
      resolveCodexHome({
        platform: 'macos',
        homeDir: '/Users/test',
        env: { CODEX_HOME: '/System' },
      }).ok,
    ).toBe(false);
    expect(
      resolveCodexHome({
        platform: 'windows',
        homeDir: 'C:\\Users\\test',
        env: { CODEX_HOME: 'C:\\Windows' },
      }).ok,
    ).toBe(false);
  });
});
