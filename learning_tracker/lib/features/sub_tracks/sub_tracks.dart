// Public surface of the sub-tracks feature (Stories 2.9 through 2.11).
// Import this barrel from outside the feature; avoid deep paths.
library sub_tracks;

// Stories 2.4 (DNI-495), 2.6 (DNI-497), 2.8 (DNI-499) and 2.9 (DNI-500).
export 'domain/services/on_home_sub_tracks.dart';
export 'domain/sub_track_home_projection.dart';
export 'presentation/controllers/sub_track_capture_controller.dart';
export 'presentation/providers/catch_up_record_controller.dart'
    show
        CatchUpRecordPhase,
        CatchUpRecordStatus,
        catchUpRecordAllOf,
        catchUpRecordStatusProvider,
        recordCatchUpAll;
export 'presentation/providers/sub_track_capture_providers.dart'
    show
        SubTrackSourceChoice,
        activePendingRefsProvider,
        captureLeaves,
        mainTrackCaptureAllowedProvider,
        pendingCapturesProvider,
        subTrackSourceChoicesProvider,
        subTrackWritesAllowedProvider;
export 'presentation/providers/sub_track_detail_actions.dart';
export 'presentation/providers/sub_track_editor_session.dart';
export 'presentation/providers/sub_track_providers.dart';
export 'presentation/providers/sub_track_session.dart';
export 'presentation/providers/up_to_picker_providers.dart'
    show
        MainTrackUpToRequest,
        SubTrackUpToRequest,
        UpToRequest,
        onHomeSubTracksProvider;
export 'presentation/screens/sub_track_detail_screen.dart';
// Manage tracks section and detail layout.
export 'presentation/widgets/also_learning_section.dart';
export 'presentation/widgets/pending_capture_rollback.dart';
export 'presentation/widgets/sub_track_capture_section.dart';
export 'presentation/widgets/sub_track_home_row.dart';
export 'presentation/widgets/sub_track_hub_section.dart';
export 'presentation/widgets/sub_track_lifecycle_sync_panel.dart';
export 'presentation/widgets/sub_track_list_detail_layout.dart';
export 'presentation/widgets/sub_track_read_only.dart';
export 'presentation/widgets/up_to_picker.dart'
    show UpToActionButton, openUpToAndRecord, showUpToPicker;
