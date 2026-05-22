<script lang="ts">
    import '../theme.css';
    import '../app.css';
    import favicon from '$lib/assets/favicon.svg';
    import { socket } from '$lib/stores/socket.svelte';
    import { auth } from '$lib/stores/auth.svelte';
    import { audioPlayer } from '$lib/engine';
    import { engineState } from '$lib/stores/engineStore';
    import { getStreamUrl } from '$lib/api';
    import { onMount } from 'svelte';
    import { generateUUID } from '$lib';

    let { children } = $props();

    let audio: HTMLAudioElement;
    let lastUpdate = 0;
    let playbackSession: string;

    const track = $derived($engineState.track?.id);
    const quality = $derived($engineState.quality);

    function init() {
        if (!auth.isAuthenticated) return;
        audioPlayer.init(audio);
        playbackSession = generateUUID();
    }

    onMount(() => {
        init();
    });

    $effect(() => {
        if (auth.token) {
            console.log('Logged in, running init');
            init();
        }
    });

    $effect(() => {
        auth.loadFromStorage();
        socket.connect();
    });

    $effect(() => {
        if (track) {
            audioPlayer.loadMetadata();
        }
    });

    $effect(() => {
        if (!track || !audioPlayer.hasAudio) return;

        audioPlayer.setNativeErrorCount(0);

        audioPlayer.setIsAdaptive(quality === 'auto');

        audioPlayer.setStreamUrl(`${getStreamUrl(track, quality)}?session=${playbackSession}`);

        const mustUseHlsJs = true;// audioPlayer.state.isAdaptive || !audioPlayer.nativelySupported;

        console.log(
            `Loading stream. Quality: ${quality}, Adaptive: ${audioPlayer.state.isAdaptive}, URL: ${audioPlayer.state.streamUrl}, UseHlsJS: ${mustUseHlsJs}, NativelySupported: ${audioPlayer.nativelySupported}`
        );

        audioPlayer.load(audioPlayer.state.streamUrl, mustUseHlsJs);

        audioPlayer.setIsPlaying(false);
        audioPlayer.setCurrentTime(0);
        audioPlayer.setDuration(audioPlayer.state.duration || 0);
    });
</script>

<svelte:head>
    <link rel="icon" href={favicon} />
    <title>Sonic Atlas</title>
</svelte:head>

{@render children?.()}

<audio
    bind:this={audio}
    onplay={() => {
        audioPlayer.setLoading(false);
        audioPlayer.setIsPlaying(true);
    }}
    onpause={() => {
        audioPlayer.setIsPlaying(false);
    }}
    ontimeupdate={() => {
        if (!audioPlayer.hasAudio || audioPlayer.state.isScrubbing) return;

        const now = performance.now();
        if (now - lastUpdate < 250) return;
        lastUpdate = now;

        audioPlayer.setCurrentTime(audioPlayer.audioCurrentTime);
    }}
    onloadedmetadata={() => {
        if (audioPlayer.hasAudio) {
            audioPlayer.setDuration(audioPlayer.state.track?.duration || audioPlayer.audioDuration);
        }
        audioPlayer.setLoading(false);
    }}
    onloadstart={() => {
        console.log('onloadstart called');
    }}
    oncanplay={() => {
        console.log('oncanplay called');
        audioPlayer.setLoading(false);
    }}
    onwaiting={() => {
        console.log('Playback waiting/buffering...');
        audioPlayer.setLoading(true);
    }}
    onplaying={() => {
        console.log('Playback resumed');
        audioPlayer.setLoading(false);
    }}
    preload="none"
></audio>