import os from 'node:os';

export function getLocalIp() {
    const nets = os.networkInterfaces();
    for (const name of Object.keys(nets)) {
        const netInfos = nets[name];
        if (!netInfos) continue;
        for (const net of netInfos) {
            if (net.family === 'IPv4' && !net.internal) {
                return net.address;
            }
        }
    }
    return '127.0.0.1';
}