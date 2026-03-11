import noticesRaw from '../../../../../THIRD_PARTY_NOTICES.md?raw';

export const load = async () => {
    const regex = /## (.*?) -- (.*?)\n\n<details>\n<summary>View License<\/summary>\n\n```(?:\w+)?\n([\s\S]*?)\n```\n\n<\/details>/g;
    
    const licenses = [];
    let match;
    while ((match = regex.exec(noticesRaw)) !== null) {
        licenses.push({
            name: match[1].trim(),
            license: match[2].trim(),
            text: match[3].trim()
        });
    }
    
    return {
        licenses
    };
};
