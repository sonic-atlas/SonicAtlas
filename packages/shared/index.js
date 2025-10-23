import { join, resolve } from 'node:path';

/**
 * @
 * @deprecated Just use `import.meta.dirname` bro since idk if this works man
 */
const __dirname = import.meta.dirname;

export const $rootDir = join(import.meta.dirname, '..', '..');
export const $envPath = resolve($rootDir, '.env');