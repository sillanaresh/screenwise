import MessageUI
import PhotosUI
import SwiftUI

/// Report a correction, tell us about a missing movie, or send feedback (spec 5.10).
/// v1 has no server, so it sends an email. Nothing is sent without the user tapping Send.
struct FeedbackSheet: View {
  let draft: FeedbackDraft
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  @State private var field = ""
  @State private var proposed = ""
  @State private var sourceLink = ""
  @State private var photoItem: PhotosPickerItem?
  @State private var photo: Data?
  @State private var showMail = false
  @State private var sent = false
  @State private var noMail = false

  var body: some View {
    NavigationStack {
      Form {
        if sent {
          Section {
            VStack(alignment: .leading, spacing: 8) {
              Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(Color.sw.success)
              Text(thanks).font(.body).foregroundStyle(Color.sw.label)
            }
            .padding(.vertical, 8)
          }
        } else {
          Section {
            Text(draft.subject).font(.headline).foregroundStyle(Color.sw.label)
            if draft.kind == .correction {
              TextField("Which spec? For example, seats", text: $field)
            }
          } header: {
            Text(headerText)
          }
          Section(draft.kind == .correction ? "What should it say?" : "Your message") {
            TextField(placeholder, text: $proposed, axis: .vertical)
              .lineLimit(3...8)
          }
          if draft.kind != .general {
            Section {
              TextField("Link to a source (optional)", text: $sourceLink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
              if draft.kind == .correction {
                PhotosPicker(selection: $photoItem, matching: .images) {
                  Label(photo == nil ? "Add a photo (optional)" : "Photo added", systemImage: "photo")
                }
              }
            } footer: {
              if draft.kind == .correction {
                Text("A photo of the screen size plaque or the projector helps us check faster.")
              }
            }
          }
          if noMail {
            Section {
              Text("Mail isn't set up on this phone. Email us at \(AppConfig.feedbackEmail).")
                .textSelection(.enabled)
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.sw.backgroundGrouped)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(sent ? "Done" : "Cancel") { dismiss() }
        }
        if !sent {
          ToolbarItem(placement: .confirmationAction) {
            Button("Send") { send() }
              .disabled(proposed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
      .onAppear { field = draft.field ?? "" }
      .onChange(of: photoItem) { _, item in
        Task { photo = try? await item?.loadTransferable(type: Data.self) }
      }
      .sheet(isPresented: $showMail) {
        MailView(
          to: AppConfig.feedbackEmail, subject: emailSubject, body: emailBody, attachment: photo
        ) { result in
          showMail = false
          if result == .sent || result == .saved { withAnimation { sent = true } }
        }
        .ignoresSafeArea()
      }
    }
  }

  private var title: String {
    switch draft.kind {
    case .correction: String(localized: "Report a correction")
    case .missingMovie: String(localized: "Tell us about a movie")
    case .general: String(localized: "Send feedback")
    }
  }

  private var headerText: String {
    switch draft.kind {
    case .correction: String(localized: "Theatre")
    case .missingMovie: String(localized: "Movie")
    case .general: String(localized: "About")
    }
  }

  private var placeholder: String {
    switch draft.kind {
    case .correction: String(localized: "For example, 644 seats")
    case .missingMovie: String(localized: "Language, release date, anything you know")
    case .general: String(localized: "What should we fix or add?")
    }
  }

  private var thanks: String {
    draft.kind == .correction
      ? String(localized: "Thanks. We'll check it against a source before changing anything.")
      : String(localized: "Thanks. We read every message.")
  }

  private var emailSubject: String { "[Screenwise] \(title): \(draft.subject)" }

  private var emailBody: String {
    var lines = ["\(headerText): \(draft.subject)"]
    if !field.isEmpty { lines.append("Spec: \(field)") }
    lines.append("")
    lines.append(proposed)
    if !sourceLink.isEmpty { lines.append("\nSource: \(sourceLink)") }
    return lines.joined(separator: "\n")
  }

  private func send() {
    if MFMailComposeViewController.canSendMail() {
      showMail = true
      return
    }
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = AppConfig.feedbackEmail
    components.queryItems = [
      URLQueryItem(name: "subject", value: emailSubject), URLQueryItem(name: "body", value: emailBody),
    ]
    if let url = components.url {
      openURL(url) { accepted in
        if accepted { withAnimation { sent = true } } else { withAnimation { noMail = true } }
      }
    } else {
      noMail = true
    }
  }
}

/// The system mail composer.
struct MailView: UIViewControllerRepresentable {
  let to: String
  let subject: String
  let body: String
  let attachment: Data?
  let onFinish: (MFMailComposeResult) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let vc = MFMailComposeViewController()
    vc.mailComposeDelegate = context.coordinator
    vc.setToRecipients([to])
    vc.setSubject(subject)
    vc.setMessageBody(body, isHTML: false)
    if let attachment { vc.addAttachmentData(attachment, mimeType: "image/jpeg", fileName: "photo.jpg") }
    return vc
  }

  func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

  final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    let onFinish: (MFMailComposeResult) -> Void
    init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }

    func mailComposeController(
      _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?
    ) {
      onFinish(result)
    }
  }
}
