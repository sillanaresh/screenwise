import Models
import SafariServices
import Scoring
import SwiftUI

/// Specs and sources (spec 5.9): one row per spec, with its provenance and sources.
struct SourcesSheet: View {
  let screen: Screen
  @Environment(AppModel.self) private var model
  @State private var expanded: Set<String> = []
  @State private var safariURL: URL?

  private var venue: Venue? { model.venue(for: screen) }

  struct Row: Identifiable {
    let id: String
    let label: String
    let value: String
    let status: Provenance
    let sourceIDs: [String]
    let alternatives: [(value: String, sourceIDs: [String])]
    let note: String?
  }

  private var rows: [Row] {
    let f = screen.fields
    var rows: [Row] = []
    func add<T>(_ id: String, _ label: String, _ field: FieldValue<T>?, format: (T) -> String) {
      guard let field else { return }
      rows.append(
        Row(
          id: id, label: label, value: field.value.map(format) ?? String(localized: "Not known"),
          status: field.status, sourceIDs: field.sourceIDs,
          alternatives: field.alternatives.map { (format($0.value), $0.sourceIDs) }, note: field.note))
    }
    add("brand", String(localized: "Format"), f.brandFormat) { $0 }
    add("width", String(localized: "Screen width"), f.widthFt) { "\(Copy.feet($0)) ft" }
    add("height", String(localized: "Screen height"), f.heightFt) { "\(Copy.feet($0)) ft" }
    add("shape", String(localized: "Shape"), f.shape) { $0.prefix(1).uppercased() + $0.dropFirst() }
    add("seats", String(localized: "Seats"), f.seats) { $0.formatted(.number.locale(Locale(identifier: "en_IN"))) }
    add("projection", String(localized: "Projection"), f.projection) { $0 }
    add("sound", String(localized: "Sound"), f.sound) { $0 }
    add("issues", String(localized: "Viewer reports"), f.knownIssues) { $0 }
    if let venue, let opened = venue.openedOn, let date = DayFormatter.date(from: opened) {
      rows.append(
        Row(
          id: "opened", label: String(localized: "Opened"),
          value: date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "en_GB"))),
          status: venue.openedSources.isEmpty ? .unverified : .sourced, sourceIDs: venue.openedSources,
          alternatives: [], note: nil))
    }
    return rows
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Kicker(text: String(localized: "Specs and sources"))
        Text([venue?.name, screen.hall].compactMap { $0 }.joined(separator: " · "))
          .font(.title2.bold())
          .foregroundStyle(Color.sw.label)
          .padding(.top, 6)
          .padding(.bottom, 8)
        ForEach(rows) { row in
          rowView(row)
          Divider().overlay(Color.sw.separator)
        }
        if HallGeometry.forScreen(screen).isEstimated {
          Text("The 3D model uses the published screen size and seat count. Row spacing and hall depth are estimated.")
            .font(.subheadline)
            .foregroundStyle(Color.sw.labelSecondary)
            .padding(.top, 14)
        }
        Button {
          model.sheet = .feedback(
            FeedbackDraft(
              kind: .correction,
              subject: [venue?.name, screen.hall].compactMap { $0 }.joined(separator: " "), field: nil))
        } label: {
          Text("See something wrong? ") + Text("Report a correction.").foregroundStyle(Color.sw.accent).bold()
        }
        .font(.subheadline)
        .foregroundStyle(Color.sw.labelSecondary)
        .buttonStyle(.plain)
        .frame(minHeight: Spacing.minHit)
        .padding(.top, 8)
      }
      .padding(.horizontal, Spacing.margin)
      .padding(.top, 28)
      .padding(.bottom, 34)
    }
    .background(Color.sw.background)
    .sheet(item: $safariURL) { url in
      SafariView(url: url).ignoresSafeArea()
    }
  }

  private func rowView(_ row: Row) -> some View {
    let isOpen = expanded.contains(row.id)
    return VStack(alignment: .leading, spacing: 8) {
      Button {
        withAnimation(Motion.select) {
          if isOpen { expanded.remove(row.id) } else { expanded.insert(row.id) }
        }
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          ProvenanceMarker(status: row.status)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
          VStack(alignment: .leading, spacing: 2) {
            Text("\(row.label): \(row.value)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Color.sw.label)
              .fixedSize(horizontal: false, vertical: true)
            Text("\(row.status.label) · \(publishers(row.sourceIDs))")
              .font(.footnote)
              .foregroundStyle(Color.sw.labelSecondary)
          }
          Spacer(minLength: 0)
          if !row.sourceIDs.isEmpty {
            Image(systemName: "chevron.down")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(Color.sw.labelTertiary)
              .rotationEffect(.degrees(isOpen ? 180 : 0))
          }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityHint(row.sourceIDs.isEmpty ? "" : "Shows the sources")

      if isOpen {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(row.sourceIDs, id: \.self) { id in sourceView(id) }
          ForEach(Array(row.alternatives.enumerated()), id: \.offset) { _, alt in
            VStack(alignment: .leading, spacing: 6) {
              Text("Another report says \(alt.value)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.sw.label)
              ForEach(alt.sourceIDs, id: \.self) { id in sourceView(id) }
            }
          }
          if let note = row.note {
            Text(note).font(.footnote).foregroundStyle(Color.sw.labelSecondary)
          }
        }
        .padding(.leading, 18)
        .padding(.bottom, 12)
        .transition(.opacity)
      }
    }
  }

  private func publishers(_ ids: [String]) -> String {
    let names = ids.compactMap { model.theatres.source($0)?.shortName }
    var seen = Set<String>()
    let unique = names.filter { seen.insert($0).inserted }
    return unique.isEmpty ? String(localized: "no source yet") : unique.joined(separator: ", ")
  }

  @ViewBuilder private func sourceView(_ id: String) -> some View {
    if let source = model.theatres.source(id) {
      VStack(alignment: .leading, spacing: 2) {
        Text(source.title).font(.footnote).foregroundStyle(Color.sw.label)
        let meta = [
          source.publisher,
          source.publishedOn.flatMap { DayFormatter.date(from: $0) }?
            .formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "en_GB"))),
        ].compactMap { $0 }.joined(separator: " · ")
        if !meta.isEmpty { Text(meta).font(.footnote).foregroundStyle(Color.sw.labelSecondary) }
        if let url = source.url {
          Button("Open source") { safariURL = url }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.sw.label)
            .underline()
            .frame(minHeight: 32)
        }
      }
    }
  }
}

extension URL: @retroactive Identifiable {
  public var id: String { absoluteString }
}

/// An in-app Safari view for source links.
struct SafariView: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
