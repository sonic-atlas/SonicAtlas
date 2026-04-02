import { apiPostFormData, getAuthHeaders, API_BASE_URL } from '$lib/api';
import type {
    FileUploadProgress,
    ReleaseUploadProgress,
    ReleaseUploadMetadata,
    UploadFilePlan,
    UploadInitResponse
} from '@sonic-atlas/shared';

export type { FileUploadProgress, ReleaseUploadProgress } from '@sonic-atlas/shared';

const CHUNK_SIZE = 50 * 1024 * 1024; // 50 MB

async function initUpload(
    metadata: ReleaseUploadMetadata,
    files: File[],
    coverFileName?: string
): Promise<UploadInitResponse> {
    const manifest = files.map((f) => ({
        fileName: f.name,
        fileSize: f.size,
        mimeType: f.type || 'application/octet-stream'
    }));

    const res = await fetch(`${API_BASE_URL}/api/uploads/init`, {
        method: 'POST',
        headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            releaseMetadata: metadata,
            files: manifest,
            coverFileName
        })
    });

    if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || `Init failed (${res.status})`);
    }

    return res.json();
}

async function uploadSmallFile(uploadId: string, fileId: string, file: File): Promise<{ trackId: string }> {
    const formData = new FormData();
    formData.append('fileId', fileId);
    formData.append('file', file);

    const res = await apiPostFormData(`/api/uploads/${uploadId}/file`, formData);

    if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || `File upload failed (${res.status})`);
    }

    return res.json();
}

async function uploadChunk(
    uploadId: string,
    fileId: string,
    chunkIndex: number,
    chunkBlob: Blob,
    maxRetries = 3
): Promise<void> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            const formData = new FormData();
            formData.append('fileId', fileId);
            formData.append('chunkIndex', chunkIndex.toString());
            formData.append('chunk', chunkBlob);

            const res = await apiPostFormData(`/api/uploads/${uploadId}/chunk`, formData);

            if (!res.ok) {
                const data = await res.json().catch(() => ({}));
                throw new Error(data.message || `Chunk upload failed (${res.status})`);
            }

            return;
        } catch (err) {
            if (attempt >= maxRetries) throw err;
            await new Promise((r) => setTimeout(r, 1000 * attempt));
        }
    }
}

async function completeChunkedFile(uploadId: string, fileId: string): Promise<{ trackId: string }> {
    const res = await fetch(`${API_BASE_URL}/api/uploads/${uploadId}/file/${fileId}/complete`, {
        method: 'POST',
        headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json'
        }
    });

    if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || `File completion failed (${res.status})`);
    }

    return res.json();
}

async function uploadFile(
    uploadId: string,
    filePlan: UploadFilePlan,
    file: File,
    onProgress: (bytesUploaded: number) => void
): Promise<{ trackId: string }> {
    if (!filePlan.needsChunking) {
        const result = await uploadSmallFile(uploadId, filePlan.fileId, file);
        onProgress(file.size);
        return result;
    }

    const totalChunks = filePlan.totalChunks;
    let bytesUploaded = 0;

    for (let i = 0; i < totalChunks; i++) {
        const start = i * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, file.size);
        const chunk = file.slice(start, end);

        await uploadChunk(uploadId, filePlan.fileId, i, chunk);

        bytesUploaded = end;
        onProgress(bytesUploaded);
    }

    return completeChunkedFile(uploadId, filePlan.fileId);
}

async function completeRelease(uploadId: string, coverFile?: File | null): Promise<{ release: any; tracks: any[] }> {
    const body = new FormData();
    if (coverFile) {
        body.append('cover', coverFile);
    }

    const res = await fetch(`${API_BASE_URL}/api/uploads/${uploadId}/complete`, {
        method: 'POST',
        headers: getAuthHeaders(),
        body
    });

    if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || `Release completion failed (${res.status})`);
    }

    return res.json();
}

const MAX_CONCURRENT_UPLOADS = 2;

export async function uploadRelease(
    metadata: ReleaseUploadMetadata,
    files: File[],
    coverFile: File | null,
    onProgress?: (progress: ReleaseUploadProgress) => void
): Promise<{ release: any; tracks: any[] }> {
    const initRes = await initUpload(metadata, files);

    const progressMap = new Map<string, FileUploadProgress>();
    for (const fp of initRes.files) {
        const file = files.find((f) => f.name === fp.fileName);
        progressMap.set(fp.fileId, {
            fileId: fp.fileId,
            fileName: fp.fileName,
            bytesUploaded: 0,
            bytesTotal: file?.size ?? 0,
            status: 'pending'
        });
    }

    const emitProgress = () => {
        const allFiles = Array.from(progressMap.values());
        const totalBytes = allFiles.reduce((s, f) => s + f.bytesTotal, 0);
        const uploadedBytes = allFiles.reduce((s, f) => s + f.bytesUploaded, 0);
        const overallProgress = totalBytes > 0 ? Math.round((uploadedBytes / totalBytes) * 100) : 0;

        onProgress?.({
            uploadId: initRes.uploadId,
            files: allFiles,
            overallProgress
        });
    };

    emitProgress();

    const queue = [...initRes.files];
    const fileMap = new Map(files.map((f) => [f.name, f]));
    const errors: Error[] = [];

    async function processNext(): Promise<void> {
        while (queue.length > 0) {
            const filePlan = queue.shift()!;
            const file = fileMap.get(filePlan.fileName);

            if (!file) {
                errors.push(new Error(`File not found: ${filePlan.fileName}`));
                continue;
            }

            const progress = progressMap.get(filePlan.fileId)!;
            progress.status = 'uploading';
            emitProgress();

            try {
                await uploadFile(initRes.uploadId, filePlan, file, (bytesUploaded) => {
                    progress.bytesUploaded = bytesUploaded;
                    emitProgress();
                });

                progress.status = 'processing';
                progress.bytesUploaded = progress.bytesTotal;
                emitProgress();

                progress.status = 'complete';
                emitProgress();
            } catch (err: any) {
                progress.status = 'error';
                progress.error = err.message;
                emitProgress();
                errors.push(err);
            }
        }
    }

    const workers = Array.from({ length: Math.min(MAX_CONCURRENT_UPLOADS, initRes.files.length) }, () => processNext());
    await Promise.all(workers);

    if (errors.length > 0 && errors.length === initRes.files.length) {
        throw new Error(`All file uploads failed. First error: ${errors[0].message}`);
    }

    return completeRelease(initRes.uploadId, coverFile);
}
