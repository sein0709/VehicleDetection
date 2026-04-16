import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let width: CGFloat = min(1440, screenFrame.width * 0.85)
    let height: CGFloat = min(900, screenFrame.height * 0.85)
    let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
    let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
    self.setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)

    self.minSize = NSSize(width: 800, height: 600)
    self.title = "GreyEye"
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
