import { browser } from '$app/environment';

let token = $state<string | null>(null);
let tokenExpiry = $state<number | null>(null);

export const auth = {
    get token() {
        return token;
    },
    get isAuthenticated() {
        if (!token || !tokenExpiry) return false;
        return Date.now() < tokenExpiry;
    },
    setToken(newToken: string, expiresIn: string = '168h') {
        token = newToken;

        const hours = parseInt(expiresIn);
        tokenExpiry = Date.now() + hours * 60 * 60 * 1000;

        if (browser) {
            localStorage.setItem('authToken', newToken);
            localStorage.setItem('tokenExpiry', tokenExpiry.toString());
        }
    },
    clearToken() {
        token = null;
        tokenExpiry = null;
        if (browser) {
            localStorage.removeItem('authToken');
            localStorage.removeItem('tokenExpiry');
        }
    },
    loadFromStorage() {
        if (browser) {
            const storedToken = localStorage.getItem('authToken');
            const storedExpiry = localStorage.getItem('tokenExpiry');

            if (storedToken && storedExpiry) {
                const expiry = parseInt(storedExpiry);

                if (Date.now() < expiry) {
                    token = storedToken;
                    tokenExpiry = expiry;
                } else {
                    this.clearToken();
                }
            }
        }
    }
};

if (browser) {
    auth.loadFromStorage();
}
