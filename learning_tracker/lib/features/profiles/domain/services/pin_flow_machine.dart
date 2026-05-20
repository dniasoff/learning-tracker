/// PIN flow state machine — domain skeleton (W2.19).
///
/// This is a pure domain stub. The full implementation lands in W4.11,
/// which will expand this into a proper `PinFlowMachine` with
/// `SetParentPinUseCase` and `VerifyParentPinUseCase`.
///
/// The thin Riverpod adapter remains in
/// `features/profiles/presentation/providers/pin_flow_controller.dart`
/// (a legacy shim that delegates to [PinService]) until W4.11 lands.
library pin_flow_machine;

export 'pin_service.dart';
