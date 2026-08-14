// The former TextDownloadProgress.notStarted progress test was retired after
// verifying that TextDownloadProgress and TextDownloadState have no current
// declarations under lib/, and that content is now read from the bundled
// cache through TextCacheRepository.
// The former TextDownloadProgress.storing ratio test was retired for the same
// verified reason: the current read-only cache has no storing/progress state.
// The former zero-total storing test was retired for the same verified reason:
// no current production API models an in-progress download.
// The former completed-state progress test was retired after verifying that
// no TextDownloadProgress/TextDownloadState declarations remain in lib/.
// The former failed-state progress test was retired after verifying that no
// current production API exposes a failed download state.
// The former isDownloaded delegation test was retired after verifying that
// TextDownloadStatusDao and its isDownloaded method were removed; the current
// ContentTextCacheDao is read-only and exposes text-cache lookups instead.
// The former not-downloaded test was retired for the same verified reason:
// current content is pre-bundled and has no download-status API.
// The former downloadCurriculum completion-stream test was retired after
// verifying that TextDownloadService and downloadCurriculum no longer exist;
// current production reads pre-bundled content through TextCacheRepository.
void main() {}
