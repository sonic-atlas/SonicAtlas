import { PUBLIC_API_URL } from '$env/static/public';
import { auth } from './stores/auth.svelte';
import type { Quality } from './types';

const API_BASE_URL = PUBLIC_API_URL || 'http://localhost:3000';

export function getAuthHeaders(): HeadersInit {
    const token = auth.token;
    if (!token) {
        throw new Error('Not authenticated');
    }
    return {
        Authorization: `Bearer ${token}`
    };
}

export async function apiFetch(path: string, options: RequestInit & { customFetch?: typeof fetch } = {}): Promise<Response> {
    const authHeaders = getAuthHeaders();
    const headers = { ...authHeaders, ...options.headers };
    const fetchImpl = options.customFetch || fetch;
    const { customFetch, ...fetchOptions } = options;
    return fetchImpl(`${API_BASE_URL}${path}`, {
        ...fetchOptions,
        headers
    });
}

export async function apiGet(path: string): Promise<Response> {
    return apiFetch(path);
}

export async function apiPost(
    path: string,
    body?: BodyInit,
    additionalHeaders?: HeadersInit
): Promise<Response> {
    const headers = { ...getAuthHeaders(), ...additionalHeaders };

    return fetch(`${API_BASE_URL}${path}`, {
        method: 'POST',
        headers,
        body
    });
}

export async function apiPostFormData(path: string, formData: FormData): Promise<Response> {
    const headers = getAuthHeaders();

    return fetch(`${API_BASE_URL}${path}`, {
        method: 'POST',
        headers: headers as HeadersInit,
        body: formData
    });
}

export async function apiPatch(
    path: string,
    body?: BodyInit,
    additionalHeaders?: HeadersInit
): Promise<Response> {
    const headers = { ...getAuthHeaders(), ...additionalHeaders };

    return fetch(`${API_BASE_URL}${path}`, {
        method: 'PATCH',
        headers,
        body
    });
}

export async function apiDelete(
    path: string,
    additionalHeaders?: HeadersInit
): Promise<Response> {
    const headers = { ...getAuthHeaders(), ...additionalHeaders };

    return fetch(`${API_BASE_URL}${path}`, {
        method: 'DELETE',
        headers
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

export function getStreamUrl(trackId: string, quality: Quality): string {
    if (!auth.token) {
        throw new Error('Not authenticated');
    }

    if (quality === 'auto') {
        return `${API_BASE_URL}/api/stream/${trackId}/master.m3u8`;
    }
    return `${API_BASE_URL}/api/stream/${trackId}/${quality}/${quality}.m3u8`;
}

export { API_BASE_URL };
