part of '../now_playing_screen.dart';

class _WaveProgressBar
    extends StatelessWidget {

  final double progress;

  final Color activeColor;
  final Color inactiveColor;

  final String currentTime;
  final String totalTime;

  final ValueChanged<double>
      onChanged;

  const _WaveProgressBar({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.currentTime,
    required this.totalTime,
    required this.onChanged,
  });

  void _updateProgress(
    Offset position,
    double width,
  ) {
    final double value =
        (position.dx / width)
            .clamp(0.0, 1.0);

    onChanged(value);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final double width =
            constraints.maxWidth;

        return Column(
          children: [

            GestureDetector(
              behavior:
                  HitTestBehavior.opaque,

              onTapDown: (
                details,
              ) {
                _updateProgress(
                  details.localPosition,
                  width,
                );
              },

              onHorizontalDragUpdate: (
                details,
              ) {
                _updateProgress(
                  details.localPosition,
                  width,
                );
              },

              child:
                  SizedBox(
                width:
                    width,

                height:
                    42,

                child:
                    CustomPaint(
                  painter:
                      _WaveformPainter(
                    progress:
                        progress,
                    activeColor:
                        activeColor,
                    inactiveColor:
                        inactiveColor,
                  ),
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 2,
              ),

              child:
                  Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                children: [

                  Text(
                    currentTime,

                    style:
                        TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                            alpha: 0.55,
                          ),
                    ),
                  ),

                  Text(
                    totalTime,

                    style:
                        TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                            alpha: 0.55,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==================================================================
// PAINTER: WAVEFORM
// ==================================================================
class _WaveformPainter
    extends CustomPainter {

  final double progress;

  final Color activeColor;
  final Color inactiveColor;

  const _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final double width =
        size.width;

    final double centerY =
        size.height / 2;

    const double amplitude =
        6.5;

    const double frequency =
        0.055;

    final double activeWidth =
        width *
            progress.clamp(
              0.0,
              1.0,
            );

    Path createWave(
      double endX,
    ) {
      final Path path =
          Path();

      final int maxX =
          endX.ceil();

      for (
        int x = 0;
        x <= maxX;
        x++
      ) {
        final double dx =
            x.toDouble();

        final double wave =
            centerY +
                amplitude *
                    math.sin(
                      dx * frequency,
                    );

        if (x == 0) {
          path.moveTo(
            dx,
            wave,
          );
        } else {
          path.lineTo(
            dx,
            wave,
          );
        }
      }

      return path;
    }

    // ============================================================
    // INACTIVE WAVE
    // ============================================================

    final Paint inactivePaint =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap =
              StrokeCap.round
          ..color =
              inactiveColor;

    canvas.drawPath(
      createWave(width),
      inactivePaint,
    );

    // ============================================================
    // ACTIVE WAVE
    // ============================================================

    if (activeWidth > 0) {
      final Paint activePaint =
          Paint()
            ..style =
                PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeCap =
                StrokeCap.round
            ..color =
                activeColor;

      canvas.drawPath(
        createWave(
          activeWidth,
        ),
        activePaint,
      );
    }

    // ============================================================
    // THUMB
    // ============================================================

    final double thumbX =
        activeWidth;

    final double thumbY =
        centerY +
            amplitude *
                math.sin(
                  thumbX *
                      frequency,
                );

    // ============================================================
    // THUMB GLOW
    // ============================================================

    final Paint glowPaint =
        Paint()
          ..color =
              activeColor.withValues(
            alpha: 0.20,
          )
          ..maskFilter =
              const MaskFilter.blur(
            BlurStyle.normal,
            5,
          );

    canvas.drawCircle(
      Offset(
        thumbX,
        thumbY,
      ),
      13,
      glowPaint,
    );

    // ============================================================
    // THUMB
    // ============================================================

    final Paint thumbPaint =
        Paint()
          ..color =
              activeColor;

    canvas.drawCircle(
      Offset(
        thumbX,
        thumbY,
      ),
      10,
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _WaveformPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
            progress ||
        oldDelegate.activeColor !=
            activeColor ||
        oldDelegate.inactiveColor !=
            inactiveColor;
  }
}

// ==================================================================
// WIDGET: PLAYER CONTROL
// ==================================================================
