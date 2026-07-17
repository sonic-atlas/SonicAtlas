declare module '@jamescoyle/svelte-icon/src/svg-icon.svelte' {
    import type { SVGAttributes } from 'svelte/elements';
    import type { Component } from 'svelte';
    interface IconProps extends SVGAttributes<SVGElement> {
        path: string;
        type?: 'mdi' | 'simple-icons' | 'default';
        size?: string | number;
        viewbox?: string;
        flip?: 'none' | 'horizontal' | 'vertical' | 'both';
        rotate?: string | number;
    }

    const Icon: Component<IconProps>;
    export default Icon;
}

declare module '@jamescoyle/svelte-icon' {
    import Icon from '@jamescoyle/svelte-icon/src/svg-icon.svelte';
    export default Icon;
}
