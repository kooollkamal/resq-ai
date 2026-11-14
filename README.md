# ResQ AI

Intelligent emergency assistant for India, built with Flutter (Android).

## Features
- Emergency Route: ranks nearby hospitals (OpenStreetMap + OSRM) and draws the best route
- Find Hospital: nearby hospital list with Call and Navigate
- Safe Route (Algorithm Lab): Dijkstra and A* on the real road graph, compared with OSRM
- Emergency Info: one-tap dialer for 112, 108, 101, 100, 181, 1098

## Run
    flutter pub get
    flutter run

## Build APK
    flutter build apk --release

The APK is at build/app/outputs/flutter-apk/app-release.apk.

## Data sources
OpenStreetMap (Overpass API), OSRM public server, flutter_map.

## Limitations
No live traffic. The hospital ranking is a weighted score, not a trained model.