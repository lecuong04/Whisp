import 'package:flutter/material.dart';

class ColorSlider extends StatefulWidget {
  final ValueChanged<Color> onColorChanged;
  final Color? color;

  const ColorSlider({super.key, required this.onColorChanged, this.color});

  @override
  State<ColorSlider> createState() => _ColorSliderState();
}

class _ColorSliderState extends State<ColorSlider> {
  double sliderValue = 0;

  /// Chuyển giá trị slider (0..360) thành màu RGB
  static Color getColorFromValue(double value) {
    return HSVColor.fromAHSV(1.0, value, 1.0, 1.0).toColor();
  }

  @override
  void initState() {
    if (widget.color != null) {
      sliderValue = HSVColor.fromColor(widget.color!).hue;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          colors: List.generate(
            361,
            (hue) => HSVColor.fromAHSV(1.0, hue.toDouble(), 1.0, 1.0).toColor(),
          ),
        ).createShader(bounds);
      },
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 12,
          thumbColor: getColorFromValue(sliderValue),
          overlayColor: Colors.white,
          overlayShape: RoundSliderThumbShape(),
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        ),
        child: Slider(
          min: 0,
          max: 360,
          value: sliderValue,
          onChanged: (value) {
            widget.onColorChanged(getColorFromValue(value));
            setState(() {
              sliderValue = value;
            });
          },
        ),
      ),
    );
  }
}
