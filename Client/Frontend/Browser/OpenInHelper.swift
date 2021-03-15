// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import MobileCoreServices
import PassKit
import WebKit
import QuickLook
import Shared
import UniformTypeIdentifiers

struct MIMEType {
    static let Bitmap = UTType.bmp.preferredMIMEType ?? "image/bmp"
    static let CSS = "text/css"
    static let GIF = UTType.gif.preferredMIMEType ?? "image/gif"
    static let JavaScript = UTType.javaScript.preferredMIMEType ?? "text/javascript"
    static let JPEG = UTType.jpeg.preferredMIMEType ?? "image/jpeg"
    static let HTML = UTType.html.preferredMIMEType ?? "text/html"
    static let OctetStream = "application/octet-stream"
    static let Passbook = "application/vnd.apple.pkpass"
    static let PDF = UTType.pdf.preferredMIMEType ?? "application/pdf"
    static let PlainText = UTType.plainText.preferredMIMEType ?? "text/plain"
    static let PNG = UTType.png.preferredMIMEType ?? "image/png"
    static let WebP = UTType.webP.preferredMIMEType ?? "image/webp"
    static let Calendar = "text/calendar"
    static let USDZ = UTType.usdz.preferredMIMEType ?? "model/vnd.usdz+zip"
    static let Reality = UTType.realityFile.preferredMIMEType ?? "model/vnd.reality"
    static let XML = UTType.xml.preferredMIMEType ?? "application/xml"
    static let HEIF = UTType.heif.preferredMIMEType ?? "image/heif"
    static let HEIC = UTType.heic.preferredMIMEType ?? "image/heic"

    private static let webViewViewableTypes: [String] = [MIMEType.Bitmap, MIMEType.GIF, MIMEType.JPEG, MIMEType.HTML, MIMEType.PDF, MIMEType.PlainText, MIMEType.PNG, MIMEType.WebP, MIMEType.HEIF, MIMEType.HEIC]

    static func canShowInWebView(_ mimeType: String) -> Bool {
        return webViewViewableTypes.contains(mimeType.lowercased())
    }

    static func mimeTypeFromFileExtension(_ fileExtension: String) -> String {
        let uti = UTType.types(tag: fileExtension, tagClass: .filenameExtension, conformingTo: nil)
        if !uti.isEmpty, let mimeType = uti[0].preferredMIMEType {
            return mimeType as String
        }

        return MIMEType.OctetStream
    }

    static func fileExtensionFromMIMEType(_ mimeType: String) -> String? {
        let uti = UTType.types(tag: mimeType, tagClass: .mimeType, conformingTo: nil)
        if !uti.isEmpty, let fileExtension = uti[0].preferredFilenameExtension {
            return fileExtension as String
        }
        return nil
    }
}

class DownloadHelper: NSObject {
    fileprivate let request: URLRequest
    fileprivate let preflightResponse: URLResponse
    fileprivate let cookieStore: WKHTTPCookieStore
    fileprivate let browserViewController: BrowserViewController

    static func requestDownload(url: URL, tab: Tab) {
        tab.webView?.startDownload(using: URLRequest(url: url)) { download in
            download.delegate = tab.browserViewController
        }
//        let safeUrl = url.absoluteString.replacingOccurrences(of: "'", with: "%27")
//        tab.webView?.evaluateJavascriptInDefaultContentWorld("window.__firefox__.download('\(safeUrl)', '\(UserScriptManager.appIdToken)')")
        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .downloadLinkButton)
    }
    
    required init?(request: URLRequest?, response: URLResponse, cookieStore: WKHTTPCookieStore, canShowInWebView: Bool, forceDownload: Bool, browserViewController: BrowserViewController) {
        guard let request = request else {
            return nil
        }

        let mimeType = response.mimeType ?? MIMEType.OctetStream
        let isAttachment = mimeType == MIMEType.OctetStream

        // Bug 1474339 - Don't auto-download files served with 'Content-Disposition: attachment'
        // Leaving this here for now, but commented out. Checking this HTTP header is
        // what Desktop does should we ever decide to change our minds on this.
        // let contentDisposition = (response as? HTTPURLResponse)?.allHeaderFields["Content-Disposition"] as? String
        // let isAttachment = contentDisposition?.starts(with: "attachment") ?? (mimeType == MIMEType.OctetStream)

        guard isAttachment || !canShowInWebView || forceDownload else {
            return nil
        }

        self.cookieStore = cookieStore
        self.request = request
        self.preflightResponse = response
        self.browserViewController = browserViewController
    }

    func open() {
        guard let url = request.url, let host = url.host else {
            return
        }

        guard let download = HTTPDownload(cookieStore: cookieStore, preflightResponse: preflightResponse, request: request) else {
            return
        }

        let expectedSize = download.totalBytesExpected != nil ? ByteCountFormatter.string(fromByteCount: download.totalBytesExpected!, countStyle: .file) : nil

        var filenameItem: PhotonActionSheetItem
        if let expectedSize = expectedSize {
            let expectedSizeAndHost = "\(expectedSize) — \(host)"
            filenameItem = PhotonActionSheetItem(title: download.filename, text: expectedSizeAndHost, iconString: "file", iconAlignment: .right, bold: true)
        } else {
            filenameItem = PhotonActionSheetItem(title: download.filename, text: host, iconString: "file", iconAlignment: .right, bold: true)
        }
        filenameItem.customHeight = { _ in
            return 80
        }
        filenameItem.customRender = { label, contentView in
            label.numberOfLines = 2
            label.font = DynamicFontHelper.defaultHelper.DeviceFontSmallBold
            label.lineBreakMode = .byCharWrapping
        }

        let downloadFileItem = PhotonActionSheetItem(title: .OpenInDownloadHelperAlertDownloadNow, iconString: "download") { _, _ in
            self.browserViewController.downloadQueue.enqueue(download)
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .downloadNowButton)
        }

        let openInItem = PhotonActionSheetItem(title: .OpenInDownloadHelperAlertOpenIn) { _, _ in
            let helper = ShareExtensionHelper(url: url, tab: nil)
            let controller = helper.createActivityViewController { (_, _) in }
            self.browserViewController.present(controller, animated: true, completion: nil)
        }

        let actions = [[filenameItem], [downloadFileItem], [openInItem]]

        browserViewController.presentSheetWith(title: download.filename, actions: actions, on: browserViewController, from: browserViewController.urlBar, closeButtonTitle: .CancelString, suppressPopover: true)
    }
}

class OpenPassBookHelper: NSObject {
    fileprivate var url: URL

    fileprivate let browserViewController: BrowserViewController
    fileprivate let cookieStore: WKHTTPCookieStore
    fileprivate lazy var session = makeURLSession(userAgent: UserAgent.defaultClientUserAgent, configuration: .ephemeral)

    required init?(request: URLRequest?, response: URLResponse, cookieStore: WKHTTPCookieStore, canShowInWebView: Bool, forceDownload: Bool, browserViewController: BrowserViewController) {
        guard let mimeType = response.mimeType, mimeType == MIMEType.Passbook, PKAddPassesViewController.canAddPasses(),
            let responseURL = response.url, !forceDownload else { return nil }
        self.url = responseURL
        self.browserViewController = browserViewController
        self.cookieStore = cookieStore
        super.init()
    }

    func open() {
        self.cookieStore.getAllCookies { [self] cookies in
            for cookie in cookies {
                self.session.configuration.httpCookieStorage?.setCookie(cookie)
            }
            self.session.dataTask(with: self.url) { (data, response, error) in
                guard let _ = validatedHTTPResponse(response, statusCode: 200..<300), let data = data else {
                    self.presentErrorAlert()
                    return
                }
                self.open(passData: data)
            }.resume()
        }
    }

    private func open(passData: Data) {
        do {
            let pass = try PKPass(data: passData)

            let passLibrary = PKPassLibrary()
            if passLibrary.containsPass(pass) {
                UIApplication.shared.open(pass.passURL!, options: [:])
            } else {
                if let addController = PKAddPassesViewController(pass: pass) {
                    browserViewController.present(addController, animated: true, completion: nil)
                } else {
                    presentErrorAlert(pass: pass)
                }
            }
        } catch {
            presentErrorAlert()
            return
        }
    }
    
    private func presentErrorAlert(pass: PKPass? = nil) {
        let detail = pass == nil ? "" : " \(pass!.localizedName) \(pass!.localizedDescription)"
        let message = .UnableToAddPassErrorMessage + detail
        let alertController = UIAlertController(title: .UnableToAddPassErrorTitle, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: .UnableToAddPassErrorDismiss, style: .cancel) { (action) in
                // Do nothing.
        })
        browserViewController.present(alertController, animated: true, completion: nil)
    }
}

class OpenQLPreviewHelper: NSObject, QLPreviewControllerDataSource {
    var url: NSURL

    fileprivate let browserViewController: BrowserViewController

    fileprivate let previewController: QLPreviewController

    required init?(request: URLRequest?, response: URLResponse, canShowInWebView: Bool, forceDownload: Bool, browserViewController: BrowserViewController) {
        guard let mimeType = response.mimeType,
                 (mimeType == MIMEType.USDZ || mimeType == MIMEType.Reality),
                 let responseURL = response.url as NSURL?,
                 !forceDownload,
                 !canShowInWebView else { return nil }
        self.url = responseURL
        self.browserViewController = browserViewController
        self.previewController = QLPreviewController()
        super.init()
    }

    func open() {
        self.previewController.dataSource = self
        ensureMainThread {
            self.browserViewController.present(self.previewController, animated: true, completion: nil)
        }
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.url
    }
}
