import BetterWisprCore
import SwiftUI

struct NotesPromptSettings: View {
    @Bindable var model: AppModel
    @State private var draft = ""

    static let languages = ["nl", "en", "de", "fr", "es", "it", "pt"]

    var body: some View {
        Picker("Notes language", selection: setting(\.notesLanguage)) {
            Text("Same as the meeting").tag(String?.none)
            ForEach(languageCodes, id: \.self) { code in
                Text(Self.name(of: code)).tag(String?.some(code))
            }
        }
        Picker("Your instructions", selection: setting(\.notesInstructionsMode)) {
            Text("Add to the built-in prompt").tag(NotesInstructionsMode.append)
            Text("Replace the built-in prompt").tag(NotesInstructionsMode.replace)
        }
        TextEditor(text: $draft)
            .font(.body)
            .frame(minHeight: 120)
        HStack {
            Button("Insert built-in prompt") { draft = MeetingNotesGenerator.defaultInstructions }
            Button("Clear") { draft = "" }
        }
        Text(caption).font(.caption).foregroundStyle(.secondary)
        Toggle(isOn: setting(\.notesUseVocabulary)) {
            Text("Use my vocabulary as a spelling reference")
            Text("Sends your vocabulary terms and known mishearings with the meeting text, so names and jargon come out spelled right. The model only uses a term where the meeting clearly said it.")
        }
        Color.clear.frame(height: 0)
            .onAppear { draft = model.settings.notesInstructions }
            // Saving also re-applies the Dock, shortcut and login item, so wait until typing pauses.
            .task(id: draft) {
                guard draft != model.settings.notesInstructions else { return }
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                model.settings.notesInstructions = draft
                model.saveNotesSettings()
            }
    }

    private var languageCodes: [String] {
        guard let saved = model.settings.notesLanguage, !Self.languages.contains(saved) else { return Self.languages }
        return Self.languages + [saved]
    }

    private var caption: String {
        switch model.settings.notesInstructionsMode {
        case .append:
            "Added after the built-in prompt, for example \"Use short bullets\" or \"List open questions under key points\". The notes language is always added last."
        case .replace:
            "Replaces the built-in prompt; left empty, the built-in prompt is used. The notes always keep their title, overview, key points, decisions and action items, and the notes language is always added last."
        }
    }

    static func name(of code: String) -> String {
        let english = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
        let native = Locale(identifier: code).localizedString(forLanguageCode: code) ?? english
        return english == native ? english : "\(english) · \(native)"
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: keyPath] }, set: { model.settings[keyPath: keyPath] = $0; model.saveNotesSettings() })
    }
}
