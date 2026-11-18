import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rive/rive.dart' as rive;

import 'rook_state.dart';

class RookMascot extends StatefulWidget {
  const RookMascot({
    super.key,
    required this.state,
    this.width = 196,
    this.height = 184,
  });

  final RookState state;
  final double width;
  final double height;

  @override
  State<RookMascot> createState() => _RookMascotState();
}

class _RookMascotState extends State<RookMascot> with WidgetsBindingObserver {
  final Map<String, rive.FileLoader> _fileLoaders = {};
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final fileLoader in _fileLoaders.values) {
      fileLoader.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_isForeground == isForeground) return;
    setState(() => _isForeground = isForeground);
  }

  rive.FileLoader _fileLoaderFor(RookState state) => _fileLoaders.putIfAbsent(
    state.riveAsset,
    () => rive.FileLoader.fromAsset(
      state.riveAsset,
      riveFactory: rive.Factory.flutter,
    ),
  );

  Widget _buildFrame() => SvgPicture.asset(
    widget.state.svgAsset,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );

  void _selectSharedPose(rive.RiveWidgetController controller) {
    final machine = controller.stateMachine;
    machine.boolean('isStrained')?.value = widget.state.isStrainedInput;
    machine.boolean('isInjured')?.value = widget.state.isInjuredInput;
    machine.boolean('isQueasy')?.value = widget.state.isQueasyInput;
  }

  @override
  Widget build(BuildContext context) {
    final useStaticFrame =
        MediaQuery.of(context).disableAnimations || !_isForeground;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Semantics(
        label: '${widget.state.label} Rook',
        image: true,
        child: ExcludeSemantics(
          child: useStaticFrame
              ? _buildFrame()
              : rive.RiveWidgetBuilder(
                  key: ValueKey(widget.state.riveAsset),
                  fileLoader: _fileLoaderFor(widget.state),
                  stateMachineSelector: rive.StateMachineSelector.byName(
                    'Rook',
                  ),
                  builder: (context, state) => switch (state) {
                    rive.RiveLoaded(:final controller) => () {
                      if (widget.state.usesSharedStateMachine) {
                        _selectSharedPose(controller);
                      }
                      return rive.RiveWidget(
                        controller: controller,
                        fit: rive.Fit.contain,
                      );
                    }(),
                    rive.RiveLoading() || rive.RiveFailed() => _buildFrame(),
                  },
                ),
        ),
      ),
    );
  }
}
