#!/usr/bin/env bash
set -euo pipefail

FLUTTER_HOME="$HOME/flutter"

if [ ! -d "$FLUTTER_HOME" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release --base-href /

# Копіюємо 404.html в build/web, якщо він існує
if [ -f "404.html" ]; then
  cp 404.html build/web/404.html
  echo "404.html скопійовано в build/web/"
fi


