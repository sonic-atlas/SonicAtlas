# CONTRIBUTING
Stuff to note before contributing:
- Using state:
  - If do not need reactivity, using `audioPlayer.state.field`, not `$engineState.field`.
    ```ts
    import { audioPlayer } from '$lib/engine';

    function test() {
        // Reactivity not needed/used so use audioPlayer.state
        const duration = audioPlayer.state.duration;
    }
    ```
  - If you do need reactivity though (similar to a $state, so for UI/refreshing a `$effect`), use $derived not pure `$engineState.field`. Like this:
    ```svelte
    <script lang='ts'>
        import { engineState } from '$lib/stores/engineStore';
    
        // Only refreshes on $engineState.quality changes, not the whole $engineState
        const quality = $derived($engineState.quality);
    
        $effect(() => {
            // Refreshes on quality changes, not any change to $engineState.
            quality;
        });
    </script>

    // Same with components, value is recalculated when quality changes,
    // not the whole $engineState object.
    <md-outlined-select /* ... */ value={quality}></md-outlined-select>
    ```
> [!CAUTION]
> If you use a reactive variable inside a `$effect`, do **not** set them in that `$effect`. Doing so will result in a reactivity loop. Instead, guard with an `if` statement (if applicable), or find another way. If you cannot find another way, someone else may know so feel free to ask.
>
> The next commit will help safe guard against same value changes running the `$effect`, as we do not see a need for it.
