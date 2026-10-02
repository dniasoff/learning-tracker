// Public surface of the sub-tracks feature (Stories 2.9 and 2.10, DNI-500/501).
// Import this barrel from outside this feature; avoid deep paths.
library sub_tracks;

export 'domain/sub_track_home_projection.dart';
export 'domain/services/on_home_sub_tracks.dart';
export 'presentation/controllers/sub_track_capture_controller.dart';
export 'presentation/providers/sub_track_providers.dart';
export 'presentation/providers/sub_track_session.dart';
export 'presentation/providers/sub_track_capture_providers.dart'
    show captureLeaves, pendingCapturesProvider;
export 'presentation/providers/up_to_picker_providers.dart'
    show MainTrackUpToRequest, SubTrackUpToRequest, UpToRequest, onHomeSubTracksProvider;
export 'presentation/widgets/also_learning_section.dart';
export 'presentation/widgets/sub_track_capture_section.dart';
export 'presentation/widgets/sub_track_home_row.dart';
export 'presentation/widgets/sub_track_read_only.dart';
export 'presentation/widgets/up_to_picker.dart'
    show UpToActionButton, openUpToAndRecord, showUpToPicker;

