import { validatePackage } from '@codexpet/core';
import type {
  NestLayoutManifest,
  NestPackageManifest,
  PackageFileEntry,
  ValidationIssue,
} from '@codexpet/core';

export interface LoadNestThemeInput {
  packageManifest: NestPackageManifest;
  nestLayout: NestLayoutManifest;
  files: PackageFileEntry[];
  packageSizeBytes?: number;
}

export interface LoadNestThemeResult {
  ok: boolean;
  theme?: NestLayoutManifest;
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
}

export function loadNestTheme(input: LoadNestThemeInput): LoadNestThemeResult {
  const result = validatePackage({
    expectedType: 'codexpet.nest',
    packageManifest: input.packageManifest,
    nestLayout: input.nestLayout,
    files: input.files,
    packageSizeBytes:
      input.packageSizeBytes ?? input.files.reduce((total, file) => total + file.sizeBytes, 0),
  });

  return {
    ok: result.ok,
    theme: result.ok ? input.nestLayout : undefined,
    errors: result.errors,
    warnings: result.warnings,
  };
}
