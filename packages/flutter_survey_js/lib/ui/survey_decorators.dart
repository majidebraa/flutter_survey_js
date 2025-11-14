import 'package:flutter/material.dart';

Widget buildDecoratedElement(Widget child) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white, // background color
        borderRadius: BorderRadius.circular(12), // corner radius
        /*boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],*/
      ),
      padding: const EdgeInsets.all(12), // inner padding
      child: child,
    ),
  );
}
