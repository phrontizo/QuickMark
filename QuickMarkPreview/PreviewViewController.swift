import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        self.view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        handler(nil)
    }
}
