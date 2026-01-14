import Cocoa
import FlutterMacOS

public class VidraPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "vidra_player", binaryMessenger: registrar.messenger)
    let instance = VidraPlayerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var originalFrame: NSRect?
  private var isPip = false

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let window = NSApplication.shared.windows.first { window in
        return window.contentViewController is FlutterViewController
    }

    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "isFullscreen":
      let isFull = window?.styleMask.contains(NSWindow.StyleMask.fullScreen) ?? false
      result(isFull)
    case "toggleFullscreen":
      window?.toggleFullScreen(nil)
      let isFull = window?.styleMask.contains(NSWindow.StyleMask.fullScreen) ?? false
      result(isFull)
    case "enterFullscreen":
      if let win = window, !win.styleMask.contains(NSWindow.StyleMask.fullScreen) {
        win.toggleFullScreen(nil)
      }
      result(nil)
    case "exitFullscreen":
      if let win = window, win.styleMask.contains(NSWindow.StyleMask.fullScreen) {
        win.toggleFullScreen(nil)
      }
      result(nil)
    case "enterPip":
      if let win = window, !isPip {
        originalFrame = win.frame
        isPip = true
        win.level = NSWindow.Level.floating
        
        // Mini size (16:9)
        let miniWidth: CGFloat = 500
        let miniHeight: CGFloat = 280
        let screenFrame = win.screen?.visibleFrame ?? .zero
        let newFrame = NSRect(
            x: screenFrame.maxX - miniWidth - 20,
            y: screenFrame.minY + 20,
            width: miniWidth,
            height: miniHeight
        )
        win.setFrame(newFrame, display: true, animate: true)
      }
      result(nil)
    case "exitPip":
      if let win = window, isPip {
        isPip = false
        win.level = NSWindow.Level.normal
        if let frame = originalFrame {
          win.setFrame(frame, display: true, animate: true)
        }
      }
      result(nil)
    case "minimize":
      window?.miniaturize(nil)
      result(nil)
    case "maximize":
      if let win = window, !win.isZoomed {
        win.zoom(nil)
      }
      result(nil)
    case "restore":
        if let win = window {
            if win.isMiniaturized {
                win.deminiaturize(nil)
            } else if win.isZoomed {
                win.zoom(nil)
            }
        }
        result(nil)
    case "close":
      window?.close()
      result(nil)
    case "setTitle":
      if let args = call.arguments as? [String: Any],
         let title = args["title"] as? String {
        window?.title = title
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
