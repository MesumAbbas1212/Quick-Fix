import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

/// Direction of user-authored text, independent of the English UI or the
/// viewer's language. Hindi is non-Latin but LTR; Urdu/Arabic are RTL.
TextDirection contentDirection(String text) =>
    intl.Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
