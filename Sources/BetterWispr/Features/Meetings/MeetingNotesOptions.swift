import BetterWisprCore
import SwiftUI

struct MeetingNotesOptionsButton: View {
    @Bindable var meetings: MeetingModel
    let id: UUID
    @State private var showing = false

    var body: some View {
        Button(isCustomized ? "Notes options · Custom" : "Notes options…") { showing = true }
            .help("Language and instructions for this meeting's summary only")
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                MeetingNotesOptions(meetings: meetings, id: id)
                    .padding(16)
                    .frame(width: 420)
            }
    }

    private var isCustomized: Bool {
        guard let meeting = meetings.meeting(id) else { return false }
        return meeting.notesLanguage != nil || !(meeting.notesInstructions ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct MeetingNotesOptions: View {
    @Bindable var meetings: MeetingModel
    let id: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This meeting's summary").font(.headline)
            Picker("Language", selection: languageBinding) {
                Text("As in Models · \(modelsLanguage)").tag(String?.none)
                ForEach(languageCodes, id: \.self) { code in
                    Text(NotesPromptSettings.name(of: code)).tag(String?.some(code))
                }
            }
            Picker("Instructions", selection: field(\.replacesNotesPrompt, default: false)) {
                Text("Add to the prompt from Models").tag(false)
                Text("Replace the whole prompt").tag(true)
            }
            TextEditor(text: field(\.notesInstructions, default: ""))
                .font(.body)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Button("Insert built-in prompt") { meetings.edit(id) { $0.notesInstructions = MeetingNotesGenerator.defaultInstructions } }
                Button("Reset to Models") {
                    meetings.edit(id) {
                        $0.notesLanguage = nil
                        $0.notesInstructions = nil
                        $0.replacesNotesPrompt = nil
                    }
                }
            }
            Text("Used the next time you generate or update this summary. Other meetings keep the settings from Models.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var modelsLanguage: String {
        meetings.notesSettings.notesLanguage.map(NotesPromptSettings.name(of:)) ?? "Same as the meeting"
    }

    private var languageCodes: [String] {
        guard let saved = meetings.meeting(id)?.notesLanguage, !NotesPromptSettings.languages.contains(saved) else { return NotesPromptSettings.languages }
        return NotesPromptSettings.languages + [saved]
    }

    private func field<Value>(_ keyPath: WritableKeyPath<Meeting, Value?>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { meetings.meeting(id)?[keyPath: keyPath] ?? fallback },
            set: { value in meetings.edit(id) { $0[keyPath: keyPath] = value } }
        )
    }

    private var languageBinding: Binding<String?> {
        Binding(get: { meetings.meeting(id)?.notesLanguage }, set: { value in meetings.edit(id) { $0.notesLanguage = value } })
    }
}
