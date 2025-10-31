<script lang='ts'>
    let streamUrl = $state('http://localhost:3000/api/stream/69f1d3dd-fe34-4146-bf3d-d0d203d9ae6f?quality=high');
    let audio: HTMLAudioElement;
    let isPlaying = $state(false);

    function togglePlay() {
        if (!audio) return;

        if (isPlaying) {
            audio.pause();
        } else {
            audio.play();
        }
        isPlaying = !isPlaying;
    }
</script>

<main>
    <input type="text" bind:value={streamUrl} />
    <audio bind:this={audio} src={streamUrl} preload="none"></audio>

    <button onclick={togglePlay}>{isPlaying ? 'Pause' : 'Play'}</button>
</main>