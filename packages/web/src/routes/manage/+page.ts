import { apiFetch } from '$lib/api';

export const ssr = false;

export async function load({ fetch }) {
    const res = await apiFetch('/api/releases', { customFetch: fetch });
    if (!res.ok) {
        return { releases: [] };
    }
    const releases = await res.json();
    return { releases };
}
