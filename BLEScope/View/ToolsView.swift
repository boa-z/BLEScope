import SwiftUI

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

struct ToolsView: View {
    @AppStorage("tools_packet_templates_v1")
    private var templatesData: String = "[]"

    @State private var draftName = ""
    @State private var draftPayload = ""
    @State private var selectedTemplateId: UUID?
    @State private var showCopiedAlert = false

    private var templates: [PacketTemplate] {
        loadTemplates()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Portable Tools") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Packet Builder")
                            .font(.headline)
                        Text("Compose, save, and copy common payloads.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

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
                            copyToPasteboard(draftPayload)
                            showCopiedAlert = true
                        }
                        .disabled(draftPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Save") {
                            saveDraft()
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
                                        copyToPasteboard(template.payload)
                                        showCopiedAlert = true
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
            .navigationTitle("Tools")
            .alert("Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Payload copied to clipboard.")
            }
        }
    }

    private func loadTemplates() -> [PacketTemplate] {
        guard let data = templatesData.data(using: .utf8) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([PacketTemplate].self, from: data) {
            return decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
        return []
    }

    private func saveTemplates(_ templates: [PacketTemplate]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(templates),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        templatesData = string
    }

    private func saveDraft() {
        var current = templates
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPayload = draftPayload.trimmingCharacters(in: .whitespacesAndNewlines)

        if let selectedId = selectedTemplateId,
           let index = current.firstIndex(where: { $0.id == selectedId }) {
            current[index].name = trimmedName
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

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
