const version = process.versions.node;
const [major, minor, patch] = version.split('.').map(Number);

function cmp(a, b) {
    for (let i = 0; i < 3; i++) {
        if (a[i] !== b[i]) return a[i] - b[i];
    }
    return 0;
}

const v = [major, minor, patch];
const MIN = [22, 18, 0];
const MIN_R = 'This is because we make use of Node\'s built in TypeScript support.';
const REC = [25, 2,  0];
const REC_R = `Type stripping is still experimental in this version.\nUpgrading to ${REC.join('.')} will provide stable behaviour`;

// This check is for package managers that don't read engines.node
// e.g. Yarn v2+ (v1 warns, not errors), Bun, Deno
if (cmp(v, MIN) < 0) {
    console.error(`
Unsupported Node.js version

Detected: Node.js v${version}
Required: Node.js v${MIN.join('.')} or newer

${MIN_R}
`);
    process.exit(1);
}

if (cmp(v, REC) < 0) {
    console.warn(`
Node.js version supported, but not recommended

Detected: Node.js v${version}
Recommended: Node.js v${REC.join('.')} or newer

${REC_R}
`);
}