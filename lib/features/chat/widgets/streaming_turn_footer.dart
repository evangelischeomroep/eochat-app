import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/streaming_haptic_memory.dart';
import '../providers/queued_completion_provider.dart';
import '../views/chat_turn_render_state.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/widgets/assistant_detail_header.dart';
import '../../../shared/widgets/markdown/renderer/markdown_style.dart';

class StreamingTurnFooter extends ConsumerStatefulWidget {
  const StreamingTurnFooter({
    super.key,
    required this.message,
    this.suppressStreamingHaptics = false,
  });

  final ChatMessage message;
  final bool suppressStreamingHaptics;

  @override
  ConsumerState<StreamingTurnFooter> createState() =>
      _StreamingTurnFooterState();
}

class _StreamingTurnFooterState extends ConsumerState<StreamingTurnFooter> {
  static const Duration _switchDuration = Duration(milliseconds: 200);

  bool _disableAnimations = false;
  bool _didTriggerRunningHaptic = false;

  @override
  void didUpdateWidget(covariant StreamingTurnFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _didTriggerRunningHaptic = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = context.reduceMotion;
  }

  void _syncRunningHaptic(bool shouldShow) {
    if (!shouldShow) {
      if (_didTriggerRunningHaptic) {
        ref
            .read(streamingHapticMemoryProvider)
            .rearmRunningIndicator(widget.message.id);
      }
      _didTriggerRunningHaptic = false;
      return;
    }
    if (_didTriggerRunningHaptic) {
      return;
    }
    _didTriggerRunningHaptic = true;
    final shouldTrigger = ref
        .read(streamingHapticMemoryProvider)
        .markFired(widget.message.id, StreamingHapticEvent.runningIndicator);
    if (!shouldTrigger) {
      return;
    }
    _streamingHaptic();
  }

  void _streamingHaptic() {
    final enabled =
        ref.read(streamingHapticsEnabledProvider) &&
        !widget.suppressStreamingHaptics;
    if (enabled) ConduitHaptics.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    // Queued/offline/stalled completions keep `isStreaming: true` on the
    // assistant row while the message body shows the retry banner. Suppress
    // the timeline typing indicator in that case — the old in-message footer
    // gated on `!hasQueuedCompletion` the same way.
    final queuedCompletionAsync = ref.watch(
      queuedCompletionInfoForMessageProvider(widget.message.id),
    );
    final hasQueuedCompletion =
        queuedCompletionAsync.hasValue && queuedCompletionAsync.value != null;
    final shouldShow =
        !hasQueuedCompletion &&
        shouldShowStreamingTurnFooter(message: widget.message);
    _syncRunningHaptic(shouldShow);

    return AnimatedSwitcher(
      duration: _disableAnimations ? Duration.zero : _switchDuration,
      reverseDuration: _disableAnimations ? Duration.zero : _switchDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        final children = <Widget>[...previousChildren, ?currentChild];
        if (children.isEmpty) {
          return const SizedBox.shrink();
        }
        return Stack(
          alignment: AlignmentDirectional.topStart,
          children: children,
        );
      },
      child: shouldShow
          ? KeyedSubtree(
              key: const ValueKey('typing'),
              child: SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: ConduitMarkdownStyle.fromTheme(context)
                          .paragraphSpacing,
                      bottom: Spacing.xs,
                    ),
                    child: RepaintBoundary(
                      child: StreamingThinkingIndicator(
                        animate: !_disableAnimations,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('streaming-turn-footer-empty')),
    );
  }
}

@visibleForTesting
bool shouldShowStreamingTurnFooter({required ChatMessage message}) {
  return chatTurnPhaseShowsRunningFooter(chatTurnPhaseForMessage(message));
}

/// The "still working" cue shown while a turn is running with nothing more
/// specific to report (no tool/status row active yet).
///
/// Replaces the old dot-orbit spinner with the same shimmering-text
/// treatment [AssistantDetailHeader] already uses for reasoning/tool-call
/// headers elsewhere in this screen (see details_block_widget.dart), so the
/// "model is working" cue looks like one consistent idiom instead of two
/// different loading animations depending on whether a status row happens to
/// be present.
class StreamingThinkingIndicator extends StatelessWidget {
  const StreamingThinkingIndicator({super.key, this.animate = true});

  final bool animate;

  // Pins the row to the old orbit's exact 28px height. settle_height_test.dart
  // asserts the streaming footer (paragraphSpacing + this + Spacing.xs) is
  // pixel-equal to the settled in-card action row (paragraphSpacing +
  // ChatActionButton's 32px), i.e. this must stay exactly 28 regardless of
  // whatever the shimmer text's own intrinsic line height happens to be.
  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      // ClipRect is a safety net, not the normal case: at very large Dynamic
      // Type accessibility sizes the shimmer text's intrinsic line height can
      // exceed 28px. Align alone wouldn't clip that overflow, which would let
      // the text bleed into the row above/below instead of just being capped.
      child: ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: AssistantDetailHeader(
            title: AppLocalizations.of(context)!.thinking,
            showShimmer: animate,
            showChevron: false,
          ),
        ),
      ),
    );
  }
}
