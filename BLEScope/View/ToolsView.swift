import SwiftUI

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private struct PacketTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var payload: String
    var updatedAt: Date
}

private struct ToolsToast: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ToolsView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    NavigationLink {
                        PacketBuilderView()
                    } label: {
                        ToolCard(
                            title: "Packet Builder",
                            subtitle: "Compose, save, and copy common payloads.",
                            systemImage: "doc.badge.gearshape"
                        )
                    }
                }
                .padding(16)
            }
            .navigationTitle("Tools")
        }
    }
}

private struct ToolCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .contentShape(Rectangle())
    }

    private var cardBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}

private struct PacketBuilderView: View {
    private let storageKey = "tools_packet_templates_v1"

    @State private var draftName = ""
    @State private var draftPayload = ""
    @State private var selectedTemplateId: UUID?
    @State private var toast: ToolsToast?
    @State private var templates: [PacketTemplate] = []

    var body: some View {
        Form {
            Section("Editor") {
                TextField("Name", text: $draftName)
                TextEditor(text: $draftPayload)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 140)

                HStack {
                    Button("New") {
                        clearDraft()
                    }
                    Spacer()
                    Button("Copy") {
                        if copyToPasteboard(draftPayload) {
                            toast = ToolsToast(title: "Copied", message: "Payload copied to clipboard.")
                        } else {
                            toast = ToolsToast(title: "Copy Failed", message: "Nothing to copy.")
                        }
                    }
                    .disabled(draftPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Save") {
                        if saveDraft() {
                            toast = ToolsToast(title: "Saved", message: "Packet saved.")
                        } else {
                            toast = ToolsToast(title: "Save Failed", message: "Name and payload cannot be empty.")
                        }
                    }
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || draftPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Saved Packets") {
                if templates.isEmpty {
                    Text("No saved packets yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(templates) { template in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(template.name)
                                    .font(.headline)
                                Spacer()
                                Text(template.updatedAt, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(template.payload)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                                .foregroundColor(.secondary)

                            HStack {
                                Button("Use") {
                                    loadDraft(from: template)
                                }
                                Button("Copy") {
                                    if copyToPasteboard(template.payload) {
                                        toast = ToolsToast(title: "Copied", message: "Payload copied to clipboard.")
                                    } else {
                                        toast = ToolsToast(title: "Copy Failed", message: "Nothing to copy.")
                                    }
                                }
                                Spacer()
                                Button("Delete") {
                                    deleteTemplate(template.id)
                                }
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Packet Builder")
        .onAppear {
            loadTemplates()
        }
        .alert(item: $toast) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    private func loadTemplates() {
        let decoder = PropertyListDecoder()
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? decoder.decode([PacketTemplate].self, from: data) {
            templates = decoded.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            templates = []
        }
    }

    private func saveTemplates(_ templates: [PacketTemplate]) {
        let encoder = PropertyListEncoder()
        guard let data = try? encoder.encode(templates) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
        self.templates = templates.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    private func saveDraft() -> Bool {
        var current = templates
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPayload = draftPayload.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedPayload.isEmpty else {
            return false
        }

        if let selectedId = selectedTemplateId,
           let index = current.firstIndex(where: { $0.id == selectedId }),
           current[index].name.caseInsensitiveCompare(trimmedName) == .orderedSame {
            current[index].payload = trimmedPayload
            current[index].updatedAt = Date()
        } else if let index = current.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            current[index].payload = trimmedPayload
            current[index].updatedAt = Date()
            selectedTemplateId = current[index].id
        } else {
            let newTemplate = PacketTemplate(id: UUID(), name: trimmedName, payload: trimmedPayload, updatedAt: Date())
            current.append(newTemplate)
            selectedTemplateId = newTemplate.id
        }

        saveTemplates(current)
        return true
    }

    private func deleteTemplate(_ id: UUID) {
        var current = templates
        current.removeAll { $0.id == id }
        saveTemplates(current)
        if selectedTemplateId == id {
            clearDraft()
        }
    }

    private func loadDraft(from template: PacketTemplate) {
        draftName = template.name
        draftPayload = template.payload
        selectedTemplateId = template.id
    }

    private func clearDraft() {
        draftName = ""
        draftPayload = ""
        selectedTemplateId = nil
    }

    @discardableResult
    private func copyToPasteboard(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }
        #if canImport(UIKit)
        if #available(iOS 14.0, *) {
            UIPasteboard.general.setItems([[UTType.plainText.identifier: trimmed]])
        } else {
            UIPasteboard.general.string = trimmed
        }
        return true
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(trimmed, forType: .string)
        return true
        #else
        return false
        #endif
    }
}
