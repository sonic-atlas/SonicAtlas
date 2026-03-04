class UploadFilePlan {
  final String fileId;
  final String fileName;
  final bool needsChunking;
  final int totalChunks;
  final int chunkSize;

  UploadFilePlan({
    required this.fileId,
    required this.fileName,
    required this.needsChunking,
    required this.totalChunks,
    required this.chunkSize,
  });

  factory UploadFilePlan.fromJson(Map<String, dynamic> json) {
    return UploadFilePlan(
      fileId: json['fileId'] ?? '',
      fileName: json['fileName'] ?? '',
      needsChunking: json['needsChunking'] ?? false,
      totalChunks: json['totalChunks'] ?? 0,
      chunkSize: json['chunkSize'] ?? 0,
    );
  }
}

class UploadInitResponse {
  final String uploadId;
  final List<UploadFilePlan> files;

  UploadInitResponse({
    required this.uploadId,
    required this.files,
  });

  factory UploadInitResponse.fromJson(Map<String, dynamic> json) {
    var list = json['files'] as List? ?? [];
    List<UploadFilePlan> fileList = list
        .map((i) => UploadFilePlan.fromJson(i))
        .toList();

    return UploadInitResponse(
      uploadId: json['uploadId'] ?? '',
      files: fileList,
    );
  }
}

class FileUploadProgress {
  final String fileId;
  final String fileName;
  int bytesUploaded;
  final int bytesTotal;
  String status;
  String? error;

  FileUploadProgress({
    required this.fileId,
    required this.fileName,
    this.bytesUploaded = 0,
    required this.bytesTotal,
    this.status = 'pending',
    this.error,
  });
}

class ReleaseUploadProgress {
  final String uploadId;
  final List<FileUploadProgress> files;
  final int overallProgress;

  ReleaseUploadProgress({
    required this.uploadId,
    required this.files,
    required this.overallProgress,
  });
}
