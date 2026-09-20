import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Real interactive GLB mascot (rotate / touch).
class Zoon3DMascot extends StatelessWidget {
  const Zoon3DMascot({
    super.key,
    this.height = 220,
    this.autoRotate = true,
  });

  final double height;
  final bool autoRotate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ModelViewer(
          src: 'assets/models/zoon_mascot.glb',
          alt: 'Zoon 3D mascot',
          backgroundColor: const Color(0xff0B0E14),
          autoRotate: autoRotate,
          autoPlay: true,
          cameraControls: true,
          disableZoom: true,
          disablePan: true,
          touchAction: TouchAction.none,
          interactionPrompt: InteractionPrompt.none,
          shadowIntensity: 0.65,
          exposure: 1.05,
          cameraOrbit: '25deg 75deg 105%',
          fieldOfView: '30deg',
          debugLogging: false,
        ),
      ),
    );
  }
}
