import Models
import SwiftUI

/// You (spec 5.7): a grouped list in the Settings style.
struct YouView: View {
  @Environment(AppModel.self) private var model
  @AppStorage("appearance") private var appearance: Appearance = .system
  @State private var appearanceFeedback = 0

  var body: some View {
    @Bindable var model = model
    List {
      Section { meCard }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

      Section("Saved theatres") {
        if model.user.saved.isEmpty {
          Text("Tap the heart on any theatre to save it here.")
            .font(.subheadline)
            .foregroundStyle(Color.sw.labelSecondary)
        }
        ForEach(model.user.saved, id: \.screenID) { saved in
          if let screen = model.screen(saved.screenID) {
            Button {
              model.openTheatre(screen, film: nil)
            } label: {
              HStack(spacing: 12) {
                IconTile(
                  systemImage: "heart.fill", size: 36, background: Color.sw.accentSoft, foreground: Color.sw.accent)
                VStack(alignment: .leading, spacing: 1) {
                  Text(model.venue(for: screen)?.name ?? screen.name).foregroundStyle(Color.sw.label)
                  Text(Copy.hallLine(screen, venue: model.venue(for: screen)))
                    .font(.footnote)
                    .foregroundStyle(Color.sw.labelSecondary)
                }
              }
            }
          }
        }
        .onDelete { model.removeSaved(at: $0) }
      }
      .listRowBackground(Color.sw.backgroundGrouped)

      Section("Recently viewed") {
        if model.user.history.isEmpty {
          Text("Movies and theatres you open will show up here.")
            .font(.subheadline)
            .foregroundStyle(Color.sw.labelSecondary)
        }
        ForEach(Array(model.user.history.prefix(6)), id: \.self) { item in
          historyRow(item)
        }
      }
      .listRowBackground(Color.sw.backgroundGrouped)

      Section("Your details · optional") {
        detailField("Name", text: $model.user.details.name, prompt: "Your name", content: .name)
        detailField("Mobile", text: $model.user.details.mobile, prompt: "+91", content: .telephoneNumber)
          .keyboardType(.phonePad)
        detailField("Email", text: $model.user.details.email, prompt: "you@example.com", content: .emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
      }
      .listRowBackground(Color.sw.backgroundGrouped)

      Section("Explore") {
        row("All Hyderabad screens", subtitle: "Sizes, projectors and sound, side by side") {
          model.sheet = .allScreens
        }
        row("How we rank screens") { model.explain(.score) }
        row("Cinema tech explained") { model.sheet = .cinemaTech }
      }
      .listRowBackground(Color.sw.backgroundGrouped)

      Section("Settings") {
        Picker("Appearance", selection: $appearance) {
          ForEach(Appearance.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.menu)
        .onChange(of: appearance) { appearanceFeedback += 1 }
        row("Send feedback") {
          model.sheet = .feedback(FeedbackDraft(kind: .general, subject: String(localized: "Screenwise"), field: nil))
        }
        row("About and data sources") { model.sheet = .about }
      }
      .listRowBackground(Color.sw.backgroundGrouped)
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .listRowBackground(Color.sw.backgroundGrouped)
    .environment(\.defaultMinListRowHeight, 50)
    .background(Color.sw.background)
    .navigationTitle("You")
    .navigationBarTitleDisplayMode(.large)
    .sensoryFeedback(.selection, trigger: appearanceFeedback)
  }

  private var meCard: some View {
    let name = model.user.details.name.trimmingCharacters(in: .whitespaces)
    return HStack(spacing: 14) {
      ZStack {
        Circle().fill(Color.sw.accentSoft)
        if let initial = name.first {
          Text(String(initial).uppercased()).font(.title2.bold()).foregroundStyle(Color.sw.accent)
        } else {
          Image(systemName: "person").font(.title2).foregroundStyle(Color.sw.accent)
        }
      }
      .frame(width: 56, height: 56)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(name.isEmpty ? String(localized: "Add your name") : name)
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.sw.label)
        Text("Optional. Stays on this phone.")
          .font(.footnote)
          .foregroundStyle(Color.sw.labelSecondary)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .background(Color.sw.backgroundGrouped, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private func historyRow(_ item: UserData.HistoryItem) -> some View {
    let ago = item.at.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    switch item.kind {
    case .film:
      if let film = model.film(item.id) {
        Button {
          model.openMovie(film)
        } label: {
          HStack(spacing: 12) {
            FilmArtwork(film: film, posterWidth: 185)
              .frame(width: 44, height: 44)
              .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
              Text(film.title).foregroundStyle(Color.sw.label)
              Text("Movie · \(ago)").font(.footnote).foregroundStyle(Color.sw.labelSecondary)
            }
          }
        }
      }
    case .theatre:
      if let screen = model.screen(item.id) {
        Button {
          model.openTheatre(screen, film: item.filmID.flatMap(model.film))
        } label: {
          HStack(spacing: 12) {
            IconTile(systemImage: "rectangle", size: 44)
            VStack(alignment: .leading, spacing: 1) {
              Text(model.venue(for: screen)?.name ?? screen.name).foregroundStyle(Color.sw.label)
              Text("Theatre · \(ago)").font(.footnote).foregroundStyle(Color.sw.labelSecondary)
            }
          }
        }
      }
    }
  }

  private func detailField(
    _ label: LocalizedStringKey, text: Binding<String>, prompt: String, content: UITextContentType
  ) -> some View {
    LabeledContent(label) {
      TextField(label, text: text, prompt: Text(verbatim: prompt))
        .multilineTextAlignment(.trailing)
        .foregroundStyle(Color.sw.labelSecondary)
        .textContentType(content)
        .submitLabel(.done)
    }
  }

  private func row(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text(title).foregroundStyle(Color.sw.label)
          if let subtitle {
            Text(subtitle).font(.footnote).foregroundStyle(Color.sw.labelSecondary)
          }
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Color.sw.labelTertiary)
      }
      .contentShape(Rectangle())
    }
  }
}
