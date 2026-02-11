import SwiftUI
import GoogleMobileAds
import SafariServices
import WebKit

class GliaPlayerUIViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startGoogleMobileAdsSDK()

        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsInlineMediaPlayback = true
        webViewConfiguration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: view.bounds, configuration: webViewConfiguration)
        
        // RECOMMENDATION: Add this line so the WebView resizes with the screen (e.g. rotation)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(webView)
        
        MobileAds.shared.register(webView)
        // Set the WKUIDelegate on your WKWebView instance.
        webView.uiDelegate = self;
        // 2. Set the WKNavigationDelegate on your WKWebView instance.
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
    private func webView(
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
    
    // Add this method inside your GliaPlayer class
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        let jsCode = """
        document.documentElement.style.backgroundColor = 'black';
        document.body.style.margin = 'auto';
        document.body.style.height = window.innerHeight + 'px';
        document.body.style.display = 'flex';
        document.body.style.justifyContent = 'center';
        document.body.style.alignItems = 'center';
        
        const div = document.createElement('div');
        div.style.cssText = 'position:absolute;top:10px;left:10px;background:rgba(0,0,0,0.8);color:white;padding:10px;border-radius:5px;z-index:10000;';
        // document.body.appendChild(div);

        const container = document.querySelector('.gliaplayer-container');
        
        if (container) {
            container.style.transformOrigin = 'center center';
            
            const handleResize = () => {
                const winW = window.innerWidth;
                const winH = window.innerHeight;
                const conW = container.offsetWidth;
                const conH = container.offsetHeight;
                var percentage = 100;
                
                if (winW > winH) {
                    var newWidth = winH * conW / conH;
                    if (newWidth < winW) {
                        div.innerHTML = 'UUU';
                        percentage = (newWidth / winW) * 100;
                    }
                }
                document.body.style.width = `${percentage.toFixed(0)}%`;
            };
            
            const observer = new ResizeObserver(() => handleResize());
            observer.observe(container);
            window.addEventListener('resize', handleResize);
            handleResize();
        }
        """
        
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
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
