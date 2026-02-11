# Swift Ppackage Mmanager GliaPlayer

This document explains how to integrate the GliaPlayer iOS SDK, a WebView-based video ad player, into an iOS project.

---

## Scenarios
| Ads | Content Video|
|-------------------------|-------------------------|
|<img src="imgs/insert_ads.png" alt="insert_ads" width="200"/> |  <img src="imgs/insert_video.png" alt="insert_video" width="200"/> |
| <img src="imgs/floating_ads.png" alt="floating_ads" width="200"/>| <img src="imgs/floating_video.png" alt="floating_video" width="200"/>  |  

## Requirements

* iOS platform 14+ (Required by GliaPlayer)

---

## Step 1: Configure Google Mobile Ads SDK

In `ios/Runner/Info.plist`, add this config:

```xml
<dict>
	<key>GADIntegrationManager</key>
	<string>webview</string>
</dict>
```

---

## Step 3: Usage

```swift
import SwiftUI
import GliaPlayer

struct ContentView: View {
    var body: some View {
        // 1. ZStack is the equivalent of the outer 'Box' in Compose
        ZStack(alignment: .bottomTrailing) {
            
            // 2. The scrolling background content
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<100, id: \.self) { i in
                        if (i==1){
                            GliaPlayerView(slotKey: "gliacloud_app_test")
                                .frame(width: 320, height: 240)
                        }
                            
                            else{
                            Rectangle()
                                .fill(Color(
                                    red: Double.random(in: 0...1),
                                    green: Double.random(in: 0...1),
                                    blue: Double.random(in: 0...1)
                                ))
                                .frame(height: 320)
                                .frame(maxWidth: .infinity)
                        }
                        
                    }
                }
            }
            
            // 3. The floating player (AndroidView equivalent)
            // We set a fixed frame just like your .width(480.dp).height(320.dp)
            
        }
        .edgesIgnoringSafeArea(.all)
    }
}
```

---

---

## References

* [Google Mobile Ads - WebView integration](https://developers.google.com/admob/ios/browser/webview)