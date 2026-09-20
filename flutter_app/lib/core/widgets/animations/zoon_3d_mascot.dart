import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Real interactive GLB mascot (rotate / touch) with instant preview.
class Zoon3DMascot extends StatelessWidget {
  const Zoon3DMascot({
    super.key,
    this.height = 200,
    this.autoRotate = true,
  });

  final double height;
  final bool autoRotate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. High-quality rendered 3D preview image (Instant display, never blank)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/models/zoon_mascot_preview.png',
                  fit: BoxFit.contain,
                ),
              ),

              // 2. Interactive 3D Model on top
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ModelViewer(
                  src: 'assets/models/zoon_mascot.glb',
                  alt: 'Zoon 3D mascot',
                  backgroundColor: Colors.transparent,
                  autoRotate: autoRotate,
                  autoPlay: true,
                  cameraControls: true,
                  disableZoom: true,
                  disablePan: true,
                  shadowIntensity: 0.65,
                  exposure: 1.05,
                  debugLogging: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
