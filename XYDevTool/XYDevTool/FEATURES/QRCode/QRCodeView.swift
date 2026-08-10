//
//  QRCodeView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2026/7/9.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import UniformTypeIdentifiers

enum QRCodeContentType: String, CaseIterable, Identifiable {
    case text = "Text"
    case url = "URL"
    case wifi = "WiFi"
    case email = "Email"
    case sms = "SMS"
    case phone = "Phone"
    case vCard = "vCard"
    case appLink = "App Link"
    case event = "Event"

    var id: String { rawValue }
}

enum QRCodeCorrectionLevel: String, CaseIterable, Identifiable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "L - 7%"
        case .medium: return "M - 15%"
        case .quartile: return "Q - 25%"
        case .high: return "H - 30%"
        }
    }
}

enum QRCodeWiFiEncryption: String, CaseIterable, Identifiable {
    case wpa = "WPA"
    case wep = "WEP"
    case none = "nopass"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wpa: return "WPA/WPA2"
        case .wep: return "WEP"
        case .none: return "None"
        }
    }
}

enum QRCodeAppLinkKind: String, CaseIterable, Identifiable {
    case scheme = "App Scheme"
    case universalLink = "Universal Link"
    case appStore = "App Store URL"

    var id: String { rawValue }
}

struct QRCodeFormState {
    var plainText = "Hello QRCode"
    var url = "https://example.com"
    var wifiSSID = ""
    var wifiPassword = ""
    var wifiEncryption: QRCodeWiFiEncryption = .wpa
    var wifiHidden = false
    var emailAddress = ""
    var emailSubject = ""
    var emailBody = ""
    var smsPhone = ""
    var smsMessage = ""
    var phone = ""
    var vCardFullName = ""
    var vCardCompany = ""
    var vCardTitle = ""
    var vCardPhone = ""
    var vCardEmail = ""
    var vCardAddress = ""
    var vCardWebsite = ""
    var appLinkKind: QRCodeAppLinkKind = .scheme
    var appSchemeURL = "myapp://path"
    var appUniversalLink = "https://example.com/app/path"
    var appStoreURL = "https://apps.apple.com/app/id0000000000"
    var eventTitle = ""
    var eventLocation = ""
    var eventStartDate = Date()
    var eventEndDate = Date().addingTimeInterval(3600)
    var eventAllDay = false
    var eventNotes = ""
}

struct QRCodeView: View {
    @State private var selectedType: QRCodeContentType = .text
    @State private var form = QRCodeFormState()
    @State private var correctionLevel: QRCodeCorrectionLevel = .medium
    @State private var quietZone: Double = 4
    @State private var exportSize: Double = 1024
    @State private var qrImage: NSImage?
    @State private var statusMessage = ""
    @State private var decodedText = ""

    private let generator = QRCodeGenerator()
    private let decoder = QRCodeDecoder()

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                Divider()
                formPanel
                Divider()
                previewPanel
            }
        }
        .frame(minWidth: 920, minHeight: 620)
        .onAppear(perform: refreshQRCode)
        .onChange(of: selectedType) { refreshQRCode() }
        .onChange(of: correctionLevel) { refreshQRCode() }
        .onChange(of: quietZone) { refreshQRCode() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QRCode")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 8)

            ForEach(QRCodeContentType.allCases) { type in
                Button {
                    selectedType = type
                } label: {
                    HStack {
                        Text(type.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(selectedType == type ? Color.accentColor.opacity(0.16) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 150)
    }

    private var formPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(selectedType.rawValue)
                .font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    contentForm
                    Divider().padding(.vertical, 6)
                    settingsForm
                    Divider().padding(.vertical, 6)
                    decodeForm
                }
                .padding(.trailing, 8)
            }

            HStack {
                Button("Generate") {
                    refreshQRCode()
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Copy Content") {
                    copyContent()
                }

                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 360, maxWidth: 460)
    }

    @ViewBuilder
    private var contentForm: some View {
        switch selectedType {
        case .text:
            labeledTextEditor("Text", text: $form.plainText, minHeight: 160)
        case .url:
            labeledTextField("URL", text: $form.url, placeholder: "https://example.com")
            Text("When scheme is omitted, https:// is used for validation and QR content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .wifi:
            labeledTextField("Network Name", text: $form.wifiSSID, placeholder: "SSID")
            labeledSecureField("Password", text: $form.wifiPassword)
            Picker("Encryption", selection: $form.wifiEncryption) {
                ForEach(QRCodeWiFiEncryption.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            Toggle("Hidden network", isOn: $form.wifiHidden)
        case .email:
            labeledTextField("Email address", text: $form.emailAddress, placeholder: "name@example.com")
            labeledTextField("Subject", text: $form.emailSubject, placeholder: "Optional")
            labeledTextEditor("Body", text: $form.emailBody, minHeight: 100)
        case .sms:
            labeledTextField("Phone number", text: $form.smsPhone, placeholder: "+8613800000000")
            labeledTextEditor("Message", text: $form.smsMessage, minHeight: 100)
        case .phone:
            labeledTextField("Phone number", text: $form.phone, placeholder: "+8613800000000")
        case .vCard:
            labeledTextField("Full name", text: $form.vCardFullName, placeholder: "Required")
            labeledTextField("Company", text: $form.vCardCompany, placeholder: "Optional")
            labeledTextField("Work title", text: $form.vCardTitle, placeholder: "Optional")
            labeledTextField("Phone", text: $form.vCardPhone, placeholder: "Optional")
            labeledTextField("Email", text: $form.vCardEmail, placeholder: "Optional")
            labeledTextField("Address", text: $form.vCardAddress, placeholder: "Optional")
            labeledTextField("Website", text: $form.vCardWebsite, placeholder: "Optional")
        case .appLink:
            Picker("Link type", selection: $form.appLinkKind) {
                ForEach(QRCodeAppLinkKind.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .onChange(of: form.appLinkKind) { refreshQRCode() }

            switch form.appLinkKind {
            case .scheme:
                labeledTextField("App Scheme", text: $form.appSchemeURL, placeholder: "myapp://path?key=value")
            case .universalLink:
                labeledTextField("Universal Link", text: $form.appUniversalLink, placeholder: "https://example.com/app/path")
            case .appStore:
                labeledTextField("App Store URL", text: $form.appStoreURL, placeholder: "https://apps.apple.com/app/id123456789")
            }
        case .event:
            labeledTextField("Title", text: $form.eventTitle, placeholder: "Required")
            labeledTextField("Location", text: $form.eventLocation, placeholder: "Optional")
            Toggle("All-day event", isOn: $form.eventAllDay)
                .onChange(of: form.eventAllDay) { refreshQRCode() }
            DatePicker("Start", selection: $form.eventStartDate)
                .onChange(of: form.eventStartDate) {
                    if form.eventEndDate < form.eventStartDate {
                        form.eventEndDate = form.eventStartDate.addingTimeInterval(3600)
                    }
                    refreshQRCode()
                }
            DatePicker("End", selection: $form.eventEndDate)
                .onChange(of: form.eventEndDate) { refreshQRCode() }
            labeledTextEditor("Notes", text: $form.eventNotes, minHeight: 100)
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            Picker("Correction", selection: $correctionLevel) {
                ForEach(QRCodeCorrectionLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Quiet zone")
                    Spacer()
                    Text("\(Int(quietZone)) modules")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $quietZone, in: 0...12, step: 1)
            }

            Picker("Export size", selection: $exportSize) {
                Text("256").tag(256.0)
                Text("512").tag(512.0)
                Text("1024").tag(1024.0)
                Text("2048").tag(2048.0)
            }
            .pickerStyle(.segmented)
        }
    }

    private var decodeForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Decode")
                .font(.headline)

            HStack {
                Button("Import Image") {
                    importImageForDecoding()
                }

                Button("Clear") {
                    decodedText = ""
                }
                .disabled(decodedText.isEmpty)
            }

            if !decodedText.isEmpty {
                TextEditor(text: $decodedText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 90)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Preview")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Copy Image") {
                    copyImage()
                }
                .disabled(qrImage == nil)
                Button("Export PNG") {
                    exportPNG()
                }
                .disabled(qrImage == nil)
            }

            VStack {
                if let qrImage {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                } else {
                    Text("Enter valid content to generate QRCode")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)

            TextEditor(text: .constant(currentContent()))
                .font(.system(.caption, design: .monospaced))
                .frame(height: 110)
                .disabled(true)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusMessage.hasPrefix("Error") ? .red : .secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    private func labeledTextField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) { refreshQRCode() }
        }
    }

    private func labeledSecureField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) { refreshQRCode() }
        }
    }

    private func labeledTextEditor(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: minHeight)
                .onChange(of: text.wrappedValue) { refreshQRCode() }
        }
    }

    private func refreshQRCode() {
        let content = currentContent()
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            qrImage = nil
            statusMessage = "Error: content is empty."
            return
        }

        do {
            qrImage = try generator.generate(
                content: content,
                correctionLevel: correctionLevel.rawValue,
                moduleScale: 12,
                quietZoneModules: Int(quietZone)
            )
            statusMessage = "QRCode generated."
        } catch {
            qrImage = nil
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func currentContent() -> String {
        switch selectedType {
        case .text:
            return form.plainText
        case .url:
            return normalizedURL(form.url)
        case .wifi:
            return wifiContent()
        case .email:
            return emailContent()
        case .sms:
            return "SMSTO:\(form.smsPhone):\(form.smsMessage)"
        case .phone:
            return "tel:\(form.phone)"
        case .vCard:
            return vCardContent()
        case .appLink:
            return appLinkContent()
        case .event:
            return eventContent()
        }
    }

    private func normalizedURL(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private func wifiContent() -> String {
        let auth = form.wifiEncryption.rawValue
        return "WIFI:T:\(auth);S:\(escapeWiFi(form.wifiSSID));P:\(escapeWiFi(form.wifiPassword));H:\(form.wifiHidden ? "true" : "false");;"
    }

    private func escapeWiFi(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ":", with: "\\:")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func emailContent() -> String {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = form.emailAddress
        components.queryItems = [
            form.emailSubject.isEmpty ? nil : URLQueryItem(name: "subject", value: form.emailSubject),
            form.emailBody.isEmpty ? nil : URLQueryItem(name: "body", value: form.emailBody)
        ].compactMap { $0 }
        return components.string ?? "mailto:\(form.emailAddress)"
    }

    private func vCardContent() -> String {
        [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "FN:\(escapeVCard(form.vCardFullName))",
            form.vCardCompany.isEmpty ? nil : "ORG:\(escapeVCard(form.vCardCompany))",
            form.vCardTitle.isEmpty ? nil : "TITLE:\(escapeVCard(form.vCardTitle))",
            form.vCardPhone.isEmpty ? nil : "TEL;TYPE=WORK,VOICE:\(escapeVCard(form.vCardPhone))",
            form.vCardEmail.isEmpty ? nil : "EMAIL:\(escapeVCard(form.vCardEmail))",
            form.vCardAddress.isEmpty ? nil : "ADR;TYPE=WORK:;;\(escapeVCard(form.vCardAddress))",
            form.vCardWebsite.isEmpty ? nil : "URL:\(normalizedURL(form.vCardWebsite))",
            "END:VCARD"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private func appLinkContent() -> String {
        switch form.appLinkKind {
        case .scheme:
            return form.appSchemeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        case .universalLink:
            return normalizedURL(form.appUniversalLink)
        case .appStore:
            return normalizedURL(form.appStoreURL)
        }
    }

    private func eventContent() -> String {
        let startDate = form.eventStartDate
        let endDate = max(form.eventEndDate, startDate)
        let title = form.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//XYDevTool//QRCode Event//EN",
            "BEGIN:VEVENT",
            "UID:\(eventUID())",
            "DTSTAMP:\(formatICalendarDate(Date(), allDay: false))",
            "DTSTART\(form.eventAllDay ? ";VALUE=DATE" : ""):\(formatICalendarDate(startDate, allDay: form.eventAllDay))",
            "DTEND\(form.eventAllDay ? ";VALUE=DATE" : ""):\(formatICalendarDate(endDate, allDay: form.eventAllDay))",
            title.isEmpty ? nil : "SUMMARY:\(escapeICalendar(title))",
            form.eventLocation.isEmpty ? nil : "LOCATION:\(escapeICalendar(form.eventLocation))",
            form.eventNotes.isEmpty ? nil : "DESCRIPTION:\(escapeICalendar(form.eventNotes))",
            "END:VEVENT",
            "END:VCALENDAR"
        ]
        .compactMap { $0 }
        .joined(separator: "\r\n")
    }

    private func escapeVCard(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }

    private func eventUID() -> String {
        let source = "\(form.eventTitle)|\(form.eventLocation)|\(form.eventStartDate.timeIntervalSince1970)|\(form.eventEndDate.timeIntervalSince1970)"
        let safe = source
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(safe.isEmpty ? "event" : safe)@xydevtool.local"
    }

    private func formatICalendarDate(_ date: Date, allDay: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = allDay ? TimeZone.current : TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = allDay ? "yyyyMMdd" : "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private func escapeICalendar(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }

    private func copyContent() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentContent(), forType: .string)
        statusMessage = "Content copied."
    }

    private func copyImage() {
        guard let qrImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([qrImage])
        statusMessage = "Image copied."
    }

    private func exportPNG() {
        guard let image = try? generator.generate(
            content: currentContent(),
            correctionLevel: correctionLevel.rawValue,
            moduleScale: 16,
            quietZoneModules: Int(quietZone)
        ).resizedPixelated(to: Int(exportSize)), let data = image.pngData() else {
            statusMessage = "Error: failed to export PNG."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "QRCode.png"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                statusMessage = "PNG exported."
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func importImageForDecoding() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp, .image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            decodedText = try decoder.decode(from: url)
            statusMessage = "Image decoded."
        } catch {
            decodedText = ""
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}

final class QRCodeGenerator {
    private let context = CIContext()

    func generate(
        content: String,
        correctionLevel: String,
        moduleScale: Int,
        quietZoneModules: Int
    ) throws -> NSImage {
        guard let data = content.data(using: .utf8) else {
            throw QRCodeError.invalidContent
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel

        guard var outputImage = filter.outputImage else {
            throw QRCodeError.generationFailed
        }

        if quietZoneModules > 0 {
            outputImage = outputImage.paddedByModules(quietZoneModules)
        }

        let scale = max(1, moduleScale)
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            throw QRCodeError.generationFailed
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

final class QRCodeDecoder {
    func decode(from url: URL) throws -> String {
        guard let image = CIImage(contentsOf: url) else {
            throw QRCodeError.imageLoadFailed
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        guard let payload = request.results?.compactMap(\.payloadStringValue).first else {
            throw QRCodeError.noQRCodeFound
        }

        return payload
    }
}

enum QRCodeError: LocalizedError {
    case invalidContent
    case generationFailed
    case imageLoadFailed
    case noQRCodeFound

    var errorDescription: String? {
        switch self {
        case .invalidContent:
            return "Invalid QRCode content."
        case .generationFailed:
            return "QRCode generation failed."
        case .imageLoadFailed:
            return "Unable to load image."
        case .noQRCodeFound:
            return "No QRCode was found in the image."
        }
    }
}

private extension CIImage {
    func paddedByModules(_ modules: Int) -> CIImage {
        let extent = self.extent.integral
        let paddedExtent = extent.insetBy(dx: CGFloat(-modules), dy: CGFloat(-modules))
        let background = CIImage(color: .white).cropped(to: paddedExtent)
        let translated = transformed(by: CGAffineTransform(translationX: CGFloat(modules), y: CGFloat(modules)))
        return translated.composited(over: background)
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    func resizedPixelated(to sideLength: Int) -> NSImage? {
        let size = NSSize(width: sideLength, height: sideLength)
        guard let source = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSImage(cgImage: source, size: self.size).draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
