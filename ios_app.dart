name: Build MySard iOS IPA
on: [push, workflow_dispatch]
permissions:
  contents: write
jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - name: Create iOS App
        run: |
          flutter create --platforms=ios --org=com.ziyad.mysard mysard_ios
          cd mysard_ios
          flutter pub add http
          cp ../ios_app.dart lib/main.dart
          flutter build ios --release --no-codesign
          mkdir -p Payload
          cp -r build/ios/iphoneos/Runner.app Payload/
          zip -r MySard_iOS.ipa Payload
      - name: Publish iOS IPA
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ios-v1.0
          files: mysard_ios/MySard_iOS.ipa
