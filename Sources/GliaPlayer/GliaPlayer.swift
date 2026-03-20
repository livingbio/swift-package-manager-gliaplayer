import SwiftUI
import GoogleMobileAds
import SafariServices
import WebKit
import AVFoundation

class GliaPlayerUIViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var webView: WKWebView!
    private var isMobileAdsStartCalled = false
    private let slotKey: String
    
    init(slotKey: String) {
        self.slotKey = slotKey
        // 3. Call the superclass designated initializer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "audioObserver")
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "audioObserver", let state = message.body as? String {
                let audioSession = AVAudioSession.sharedInstance()
                
                if state == "muted" {
                    do {
                        try audioSession.setCategory(.ambient, options: [.mixWithOthers])
                        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                    } catch {
                        print("Can't start AVAudioSession: : \(error.localizedDescription)")
                    }
                } else if state == "unmuted" {
                    do {
                        try audioSession.setCategory(.playback)
                        try audioSession.setActive(true)
                    } catch {
                        print("Can't start AVAudioSession: \(error.localizedDescription)")
                    }
                }
            }
        }
    
    @objc func handleAppResignActive() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.ambient, options: [.mixWithOthers])
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Can't start AVAudioSession: \(error.localizedDescription)")
        }
    }

    @objc func handleAppBecomeActive() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
        } catch {
            print("Can't start AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startGoogleMobileAdsSDK()
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleAppResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil)

        NotificationCenter.default.addObserver(self,
            selector: #selector(handleAppBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsInlineMediaPlayback = true
        webViewConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        let contentController = WKUserContentController()
        let js = """
                document.addEventListener('volumechange', function(event) {
                    var element = event.target;
                    if (element && element.tagName === 'VIDEO') {
                        if (element.muted || element.volume === 0) {
                            window.webkit.messageHandlers.audioObserver.postMessage('muted');
                        } else {
                            window.webkit.messageHandlers.audioObserver.postMessage('unmuted');
                        }
                    }
                }, true);
                """
        
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(script)
        contentController.add(self, name: "audioObserver")
        webViewConfiguration.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: webViewConfiguration)
        
        // The WebView resizes with the screen (e.g. rotation)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(webView)
        
        MobileAds.shared.register(webView)
        // Set the WKUIDelegate on your WKWebView instance.
        webView.uiDelegate = self;
        // Set the WKNavigationDelegate on your WKWebView instance.
        webView.navigationDelegate = self
         
        guard let url = URL(string: "https://player.gliacloud.com/in-app-browser/\(self.slotKey)") else { return }
        let request = URLRequest(url: url)
        webView.load(request)
      }
    
    // Implement the WKUIDelegate method.
      func webView(
          _ webView: WKWebView,
          createWebViewWith configuration: WKWebViewConfiguration,
          for navigationAction: WKNavigationAction,
          windowFeatures: WKWindowFeatures) -> WKWebView? {
              if let url = webView.url {
                  // 3. Determine whether to optimize the behavior of the click URL.
                  if didHandleClickBehavior(
                      currentURL: url,
                      navigationAction: navigationAction) {
                    print("URL opened in SFSafariViewController.")
                  }
              }

        return nil
      }
    
    // Implement the WKNavigationDelegate method.
    internal func webView(
          _ webView: WKWebView,
          decidePolicyFor navigationAction: WKNavigationAction,
          decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
      {
          if let url = webView.url {
              // 3. Determine whether to optimize the behavior of the click URL.
              if didHandleClickBehavior(
                  currentURL: url,
                  navigationAction: navigationAction) {
                return decisionHandler(.cancel)
              }
          }

        decisionHandler(.allow)
      }
    
    func didHandleClickBehavior(
          currentURL: URL,
          navigationAction: WKNavigationAction) -> Bool {
        guard let targetURL = navigationAction.request.url else {
          return false
        }

        // Handle custom URL schemes such as itms-apps:// by attempting to
        // launch the corresponding application.
        if navigationAction.navigationType == .linkActivated {
          if let scheme = targetURL.scheme, !["http", "https"].contains(scheme) {
            UIApplication.shared.open(targetURL, options: [:], completionHandler: nil)
            return true
          }
        }

        guard let currentDomain = currentURL.host,
          let targetDomain = targetURL.host else {
          return false
        }

        // Check if the navigationType is a link with an href attribute or
        // if the target of the navigation is a new window.
        if (navigationAction.navigationType == .linkActivated ||
          navigationAction.targetFrame == nil) &&
          // If the current domain does not equal the target domain,
          // the assumption is the user is navigating away from the site.
          currentDomain != targetDomain {
          // 4. Open the URL in a SFSafariViewController.
          let safariViewController = SFSafariViewController(url: targetURL)
          present(safariViewController, animated: true)
          return true
        }

        return false
      }
    
    private func startGoogleMobileAdsSDK() {
      DispatchQueue.main.async {
        guard !self.isMobileAdsStartCalled else { return }

        self.isMobileAdsStartCalled = true

        // [START initialize_sdk]
        // Initialize the Google Mobile Ads SDK.
        MobileAds.shared.start()
        // [END initialize_sdk]
      }
    }
}

// 2. The Bridge (UIViewControllerRepresentable)
public struct GliaPlayerView: UIViewControllerRepresentable {
    public let slotKey: String
        
    public init(slotKey: String) {
        self.slotKey = slotKey
    }
    
    public func makeUIViewController(context: Context) -> UIViewController {
        // Return the instance of your UIKit view controller
        return GliaPlayerUIViewController(slotKey: slotKey)
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Updates the state of the view controller if SwiftUI state changes.
        // Leave empty if you don't need to pass data updates from SwiftUI to UIKit.
    }
}

#Preview {
    //GliaPlayer()
}
