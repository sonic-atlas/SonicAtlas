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

		if (typeof localStorage !== 'undefined') {
			localStorage.setItem('authToken', newToken);
			localStorage.setItem('tokenExpiry', tokenExpiry.toString());
		}
	},
	clearToken() {
		token = null;
		tokenExpiry = null;
		if (typeof localStorage !== 'undefined') {
			localStorage.removeItem('authToken');
			localStorage.removeItem('tokenExpiry');
		}
	},
	loadFromStorage() {
		if (typeof localStorage !== 'undefined') {
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
