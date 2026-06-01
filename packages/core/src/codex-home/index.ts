export type CodexPlatform = 'macos' | 'windows' | 'linux';

export interface ResolveCodexHomeInput {
  platform: CodexPlatform;
  env?: Record<string, string | undefined>;
  homeDir: string;
}

export interface ResolveCodexHomeResult {
  ok: boolean;
  path?: string;
  source?: 'CODEX_HOME' | 'default';
  error?: string;
}

export function resolveCodexHome(input: ResolveCodexHomeInput): ResolveCodexHomeResult {
  const raw = input.env?.CODEX_HOME?.trim();
  const source = raw ? 'CODEX_HOME' : 'default';
  const candidate = expandPath(
    raw || defaultCodexHome(input.platform, input.homeDir),
    input.homeDir,
    input.platform,
  );

  if (isProtectedPath(candidate, input.platform)) {
    return { ok: false, error: `Refusing protected Codex home path: ${candidate}` };
  }

  return { ok: true, path: normalizeSeparators(candidate, input.platform), source };
}

export function defaultCodexHome(platform: CodexPlatform, homeDir: string): string {
  const separator = platform === 'windows' ? '\\' : '/';
  return `${trimTrailingSeparator(homeDir, platform)}${separator}.codex`;
}

export function expandPath(path: string, homeDir: string, platform: CodexPlatform): string {
  const separator = platform === 'windows' ? '\\' : '/';
  if (path === '~') return trimTrailingSeparator(homeDir, platform);
  if (path.startsWith(`~${separator}`) || (platform !== 'windows' && path.startsWith('~/'))) {
    return `${trimTrailingSeparator(homeDir, platform)}${separator}${path.slice(2)}`;
  }
  return path;
}

export function isProtectedPath(path: string, platform: CodexPlatform): boolean {
  const normalized = normalizeSeparators(path, platform).toLowerCase();
  if (platform === 'windows') {
    if (/^[a-z]:\\?$/.test(normalized)) return true;
    const protectedRoots = ['c:\\windows', 'c:\\program files', 'c:\\program files (x86)'];
    return protectedRoots.some((root) => normalized === root || normalized.startsWith(`${root}\\`));
  }
  const protectedRoots = ['/', '/system', '/bin', '/sbin', '/usr', '/etc', '/var'];
  return protectedRoots.some((root) => normalized === root || normalized.startsWith(`${root}/`));
}

function normalizeSeparators(path: string, platform: CodexPlatform): string {
  return platform === 'windows' ? path.replaceAll('/', '\\') : path.replaceAll('\\', '/');
}

function trimTrailingSeparator(path: string, platform: CodexPlatform): string {
  const separator = platform === 'windows' ? '\\' : '/';
  return path.endsWith(separator) ? path.slice(0, -1) : path;
}
