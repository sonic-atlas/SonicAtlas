<script lang="ts">
    import '../theme.css';
    import '../app.css';
    import favicon from '$lib/assets/favicon.svg';
    import { socket } from '$lib/stores/socket.svelte';
    import { auth } from '$lib/stores/auth.svelte';

    let { children } = $props();

    $effect(() => {
        auth.loadFromStorage();
        socket.connect();
    });
</script>

<svelte:head>
    <link rel="icon" href={favicon} />
</svelte:head>

{@render children?.()}
