import client from 'prom-client';

export const register = new client.Registry();

client.collectDefaultMetrics({
    register/* ,
    prefix: 'sonic_atlas_' */
});