import 'package:flutter/material.dart';

enum VehicleClass {
  c01(1, 'Passenger/Mini', '승용차/미니트럭', Color(0xFF42A5F5)),
  c02(2, 'Bus', '버스', Color(0xFFEF5350)),
  c03(3, 'Truck <2.5t', '1~2.5톤 미만', Color(0xFF66BB6A)),
  c04(4, 'Truck 2.5-8.5t', '2.5~8.5톤 미만', Color(0xFFFFA726)),
  c05(5, '3-Axle', '1단위 3축', Color(0xFFAB47BC)),
  c06(6, '4-Axle', '1단위 4축', Color(0xFF26C6DA)),
  c07(7, '5-Axle', '1단위 5축', Color(0xFF8D6E63)),
  c08(8, 'Semi 4-Axle', '2단위 4축 세미', Color(0xFFEC407A)),
  c09(9, 'Full 4-Axle', '2단위 4축 풀', Color(0xFF7E57C2)),
  c10(10, 'Semi 5-Axle', '2단위 5축 세미', Color(0xFF26A69A)),
  c11(11, 'Full 5-Axle', '2단위 5축 풀', Color(0xFFD4E157)),
  c12(12, 'Semi 6-Axle', '2단위 6축 세미', Color(0xFFFF7043));

  const VehicleClass(this.code, this.labelEn, this.labelKo, this.color);

  final int code;
  final String labelEn;
  final String labelKo;
  final Color color;

  String label({bool korean = false}) => korean ? labelKo : labelEn;

  static VehicleClass? fromCode(int code) {
    for (final vc in values) {
      if (vc.code == code) return vc;
    }
    return null;
  }
}
