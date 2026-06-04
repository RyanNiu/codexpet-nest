import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();

const checks = [];

function pass(name, detail) {
  checks.push({ name, detail, ok: true });
}

function fail(name, detail) {
  checks.push({ name, detail, ok: false });
}

function check(name, condition, detail) {
  if (condition) {
    pass(name, detail);
  } else {
    fail(name, detail);
  }
}

function readJson(path) {
  return JSON.parse(readFileSync(join(root, path), 'utf8'));
}

function readText(path) {
  return readFileSync(join(root, path), 'utf8');
}

const tauriConfig = readJson('apps/desktop-tauri/src-tauri/tauri.conf.json');
const overlaySource = readText('apps/desktop-tauri/src/components/overlay/OverlayApp.tsx');
const settingsSource = readText('apps/desktop-tauri/src/components/settings/SettingsApp.tsx');
const traySource = readText('apps/desktop-tauri/src-tauri/src/tray/builder.rs');
const windowSource = readText('apps/desktop-tauri/src-tauri/src/windows/setup.rs');
const platformMacosSource = readText('apps/desktop-tauri/src-tauri/src/platform/macos.rs');
const actionsSource = readText('apps/desktop-tauri/src-tauri/src/commands/actions.rs');
const configCommandsSource = readText('apps/desktop-tauri/src-tauri/src/commands/config.rs');
const tauriLibSource = readText('apps/desktop-tauri/src-tauri/src/lib.rs');
const defaultCapability = readText('apps/desktop-tauri/src-tauri/capabilities/default.json');
const windowsBuildWorkflowPath = '.github/workflows/windows-build.yml';
const windowsBuildWorkflowExists = existsSync(join(root, windowsBuildWorkflowPath));
const windowsBuildWorkflow = windowsBuildWorkflowExists ? readText(windowsBuildWorkflowPath) : '';

check('product name', tauriConfig.productName === 'CodexPet Nest', tauriConfig.productName);
check('bundle identifier', tauriConfig.identifier === 'xyz.codexpet.nest', tauriConfig.identifier);
check('release frontend dist', tauriConfig.build?.frontendDist === '../dist', tauriConfig.build?.frontendDist);
check('release build command', tauriConfig.build?.beforeBuildCommand === 'pnpm build', tauriConfig.build?.beforeBuildCommand);
check('dev server isolated to devUrl', typeof tauriConfig.build?.devUrl === 'string', tauriConfig.build?.devUrl);
check('macOS private API enabled', tauriConfig.app?.macOSPrivateApi === true, String(tauriConfig.app?.macOSPrivateApi));
check('no static tauri windows in config', Array.isArray(tauriConfig.app?.windows) && tauriConfig.app.windows.length === 0, JSON.stringify(tauriConfig.app?.windows));

for (const icon of tauriConfig.bundle?.icon ?? []) {
  check(`bundle icon exists: ${icon}`, existsSync(join(root, 'apps/desktop-tauri/src-tauri', icon)), icon);
}

check('tray embeds menu-bar icon', traySource.includes('include_bytes!("../../icons/32x32.png")'), 'tray/builder.rs');
check('tray show overlay menu item', traySource.includes('Show Overlay'), 'tray/builder.rs');
check('tray hide overlay menu item', traySource.includes('Hide Overlay'), 'tray/builder.rs');
check('tray open settings menu item', traySource.includes('Open Settings'), 'tray/builder.rs');
check('settings close-to-hide registered', windowSource.includes('CloseRequested') && windowSource.includes('prevent_close'), 'windows/setup.rs');
check('release overlay size configured', windowSource.includes('320.0') && windowSource.includes('180.0'), 'windows/setup.rs');
check('debug overlay gated by backend config', overlaySource.includes('const isDevOverlay = config.isDebug === true'), 'OverlayApp.tsx');
check('overlay does not use Vite dev flag for debug UI', !overlaySource.includes('import.meta.env.DEV'), 'OverlayApp.tsx');
check('click-through hides quick actions', overlaySource.includes('overlay-interaction-disabled') && overlaySource.includes('Click-through is on'), 'OverlayApp.tsx');
check('production missing asset feedback is gentle', overlaySource.includes('Some local nest assets are unavailable.'), 'OverlayApp.tsx');
check('development diagnostics present', settingsSource.includes('Development Diagnostics'), 'SettingsApp.tsx');
check('follow diagnostics refresh interval', settingsSource.includes('setInterval(refreshFollowDiagnostics, 1_000)'), 'SettingsApp.tsx');
check('local snapshot UI present', settingsSource.includes('Local Snapshot'), 'SettingsApp.tsx');
check('local snapshot export command registered', tauriLibSource.includes('commands::config::export_local_snapshot'), 'src-tauri/src/lib.rs');
check('local snapshot import command registered', tauriLibSource.includes('commands::config::import_local_snapshot'), 'src-tauri/src/lib.rs');
check('local snapshot notes do not copy package assets', configCommandsSource.includes('package asset folders are not copied'), 'commands/config.rs');
check(
  'Windows click-through explicitly unimplemented',
  platformMacosSource.includes('Windows click-through is not implemented yet') &&
    platformMacosSource.includes('Err(WINDOWS_CLICK_THROUGH_NOT_IMPLEMENTED.to_string())'),
  'platform/macos.rs',
);
check('action capabilities keep shell disabled', actionsSource.includes('shell_execution_enabled: false'), 'commands/actions.rs');
check('Tauri shell capability absent', !defaultCapability.includes('shell:'), 'capabilities/default.json');
check('Windows CI workflow exists', windowsBuildWorkflowExists, windowsBuildWorkflowPath);
check('Windows CI source targets windows runner', windowsBuildWorkflow.includes('windows-latest'), windowsBuildWorkflowPath);
check(
  'Windows CI source runs usable Tauri build command',
  windowsBuildWorkflow.includes('pnpm tauri:build') ||
    windowsBuildWorkflow.includes('pnpm --filter @codexpet/desktop-tauri tauri build'),
  windowsBuildWorkflowPath,
);
check('Windows CI source does not use unavailable root tauri binary', !windowsBuildWorkflow.includes('pnpm tauri build'), windowsBuildWorkflowPath);
check('Windows CI source uploads artifacts', windowsBuildWorkflow.includes('actions/upload-artifact') && windowsBuildWorkflow.includes('codexpet-nest-windows-bundle'), windowsBuildWorkflowPath);

for (const result of checks) {
  const prefix = result.ok ? 'PASS' : 'FAIL';
  console.log(`${prefix} ${result.name}: ${result.detail}`);
}

const failed = checks.filter((result) => !result.ok);
if (failed.length > 0) {
  console.error(`Release readiness smoke failed: ${failed.length} check(s) failed.`);
  process.exit(1);
}

console.log(`Release readiness smoke passed: ${checks.length} checks.`);
