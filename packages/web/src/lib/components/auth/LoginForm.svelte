<script lang="ts">
    import { login } from '$lib/api';

    let password = $state('');
    let error = $state<string | null>(null);
    let loading = $state(false);

    async function handleSubmit(e: Event) {
        e.preventDefault();
        if (!password) return;

        loading = true;
        error = null;

        const result = await login(password);

        if (!result.success) {
            error = result.error || 'Authentication failed';
        }

        loading = false;
    }
</script>

<div class="loginContainer">
    <div class="loginForm">
        <h1>Enter server password</h1>

        <form onsubmit={handleSubmit}>
            <input
                type="password"
                bind:value={password}
                placeholder="Server password"
                disabled={loading}
            />

            <button type="submit" disabled={!password || loading}>
                {loading ? 'Verifying...' : 'Login'}
            </button>
        </form>

        {#if error}
            <div class="error">{error}</div>
        {/if}
    </div>
</div>

<style>
    .loginContainer {
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--background);
    }

    .loginForm {
        background: var(--surface-color);
        padding: 40px;
        border-radius: 12px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        width: 100%;
        max-width: 400px;
        border: 1px solid var(--text-secondary-color);
    }

    h1 {
        margin: 0 0 10px 0;
        text-align: center;
        color: var(--text-primary-color);
    }

    form {
        display: flex;
        flex-direction: column;
        gap: 15px;
    }

    input {
        padding: 12px;
        font-size: 16px;
        border: 2px solid var(--text-secondary-color);
        border-radius: 6px;
        transition: border-color 0.2s;
        background: var(--background);
        color: var(--text-primary-color);
    }

    input:focus {
        outline: none;
        border-color: var(--primary-color);
    }

    button {
        padding: 12px;
        font-size: 16px;
        background: var(--primary-color);
        color: var(--text-primary-color);
        border: none;
        border-radius: 6px;
        cursor: pointer;
        transition: opacity 0.2s;
    }

    button:hover:not(:disabled) {
        opacity: 0.9;
    }

    button:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .error {
        margin-top: 15px;
        padding: 10px;
        background: #fee;
        border: 1px solid #fcc;
        border-radius: 6px;
        color: #c33;
        text-align: center;
    }
</style>
