// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Uri currentBrowserUri() => Uri.parse(html.window.location.href);
