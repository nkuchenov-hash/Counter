import 'package:web/web.dart' as web;

/// Web implementation: play a short sine tone using Web Audio API (package:web).
void playTone({required double freq, required double duration}) {
  try {
    final context = web.AudioContext();
    final osc = context.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, context.currentTime);
    final gain = context.createGain();
    gain.gain.setValueAtTime(0, context.currentTime);
    gain.gain.linearRampToValueAtTime(0.1, context.currentTime + 0.02);
    gain.gain.linearRampToValueAtTime(0, context.currentTime + duration);
    osc.connect(gain);
    gain.connect(context.destination);
    osc.start(context.currentTime);
    osc.stop(context.currentTime + duration);
  } catch (e) {
    print('Audio fail: $e');
  }
}
