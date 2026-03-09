
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..', '..');

const workspaces = [
    { name: 'ROOT', dir: '../' },
    { name: 'BACKEND', dir: 'backend' },
    { name: 'WEB', dir: 'web' }
];

// Common licenses that we actually need attribution for
const licenses = ['MIT', 'Apache-2.0', 'BSD', 'BSD-2-Clause', 'BSD-3-Clause', 'ISC', 'MPL-2.0'];

function getDependencies(pkg) {
    return {
        ...(pkg.dependencies || {}),
        ...(pkg.devDependencies || {})
    }
}

function getLicenseInfo(pkgName, lock) {
    const entry = lock.packages?.[`node_modules/${pkgName}`];
    if (!entry) return { version: 'unknown', license: 'unknown' };
    return {
        version: entry.version || 'unknown',
        license: entry.license || entry.licenses || 'unknown'
    }
}

function needsAttribution(license) {
    if (!license) return false;
    const l = license.toString().toUpperCase();
    return licenses.some(a => l.includes(a.toUpperCase()));
}

function getLicenseText(pkgName) {
    const candidates = [
        `node_modules/${pkgName}/LICENSE`,
        `node_modules/${pkgName}/LICENSE.md`,
        `node_modules/${pkgName}/LICENSE.txt`,
    ];

    for (const rel of candidates) {
        const full = path.join(root, rel);
        if (fs.existsSync(full)) {
            return fs.readFileSync(full, 'utf-8').trim();
        }
    }

    return 'License file not found';
}

function scanWorkspace(workspace, lock) {
    const pkgPath = path.join(root, 'packages', workspace.dir, 'package.json');
    if (!fs.existsSync(pkgPath)) return [];

    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    const deps = getDependencies(pkg);

    const results = [];

    for (const dep of Object.keys(deps)) {
        const info = getLicenseInfo(dep, lock);

        if (needsAttribution(info.license)) {
            results.push({
                name: dep,
                version: info.version,
                license: info.license,
                text: getLicenseText(dep)
            });
        }
    }

    return results.sort((a, b) => a.name.localeCompare(b.name));
}

function main() {
    const lock = JSON.parse(fs.readFileSync(path.join(root, 'package-lock.json')));

    const seen = new Set();
    const packages = [];

    for (const ws of workspaces) {
        const results = scanWorkspace(ws, lock);

        for (const pkg of results) {
            const key = `${pkg.name}@${pkg.version}`;
            if (seen.has(key)) continue;

            seen.add(key);
            packages.push(pkg);
        }
    }

    packages.sort((a, b) => a.name.localeCompare(b.name));

    let md = '# THIRD PARTY NOTICES\n\n'

    for (const pkg of packages) {
        md += `## ${pkg.name}@${pkg.version} -- ${pkg.license}\n\n`;
        md += '<details>\n';
        md += '<summary>View License</summary>\n\n';
        md += '```\n';
        md += pkg.text;
        md += '\n```\n\n';
        md += '</details>\n\n';
    }

    fs.writeFileSync(path.join(root, 'THIRD_PARTY_NOTICES.md'), md);
}

main();