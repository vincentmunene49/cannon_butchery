#!/bin/bash
echo "Building Cannon Butchery Tracker for web..."
flutter build web --release --base-href "/cannon_butchery/"
echo "Build complete. Files are in build/web/"
echo "To deploy: cd build/web && git add . && git commit -m 'Update' && git push"
