import { PUBLIC_API_URL } from '$env/static/public';
import { auth } from './stores/auth.svelte';

const API_BASE_URL = PUBLIC_API_URL || 'http://localhost:3000';

export function getAuthHeaders(): HeadersInit {
    const token = auth.token;
    if (!token) {
        throw new Error('Not authenticated');
    }
    return {
        'Authorization': `Bearer ${token}`
    };
}

export async function apiGet(path: string): Promise<Response> {
    return fetch(`${API_BASE_URL}${path}`, {
        headers: getAuthHeaders()
    });
}

export async function apiPost(path: string, body?: BodyInit, additionalHeaders?: HeadersInit): Promise<Response> {
    const headers = { ...getAuthHeaders(), ...additionalHeaders };
    
    return fetch(`${API_BASE_URL}${path}`, {
        method: 'POST',
        headers,
        body
    });
}

export async function login(password: string): Promise<{ success: boolean; error?: string }> {
    try {
        const res = await fetch(`${API_BASE_URL}/api/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ password })
        });

        if (!res.ok) {
            const data = await res.json();
            return { success: false, error: data.message || 'Login failed' };
        }

        const data = await res.json();
        auth.setToken(data.token, data.expiresIn);
        return { success: true };
    } catch (err) {
        return { success: false, error: err instanceof Error ? err.message : 'Network error' };
    }
}

export function getStreamUrl(trackId: string, quality: string): string {
    const token = auth.token;
    if (!token) {
        throw new Error('Not authenticated');
    }
    return `${API_BASE_URL}/api/stream/${trackId}?quality=${quality}&token=${encodeURIComponent(token)}`;
}

export { API_BASE_URL };
