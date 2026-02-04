import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 1. Logic Layer (Data Manager)

private struct PacketTemplate: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var payload: String
    var updatedAt: Date
}

@MainActor
private class PacketDataManager {
    private let storageKey = "tools_packet_templates_v1"
    
    func load() -> [PacketTemplate] {
        let decoder = PropertyListDecoder()
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        
        do {
            let decoded = try decoder.decode([PacketTemplate].self, from: data)
            return decoded.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("[PacketDataManager] Load failed: \(error)")
            return []
        }
    }
    
    func save(_ templates: [PacketTemplate]) -> String? {
        let encoder = PropertyListEncoder()
        do {
            let data = try encoder.encode(templates)
            UserDefaults.standard.set(data, forKey: storageKey)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

// MARK: - 2. Native Components

private struct NativeTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .none // Cleaner look for "Notes" style
        textField.font = UIFont.preferredFont(forTextStyle: .headline)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NativeTextField
        init(_ parent: NativeTextField) { self.parent = parent }
        @objc func textFieldDidChange(_ textField: UITextField) {
            self.parent.text = textField.text ?? ""
        }
    }
}

private struct NativeTextView: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        #if canImport(UIKit)
        textView.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.backgroundColor = UIColor.clear // Transparent to match SwiftUI background
        #endif
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeTextView
        init(_ parent: NativeTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
        }
    }
}

// MARK: - 3. UI Layer (Root Tools View)

// MARK: - 3. UI Layer (Root Tools View)

// MARK: - 3. UI Layer (Root Tools View)

struct ToolsView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    NavigationLink(destination: PacketListView()) {
                        ToolCard(
                            title: "Packet Builder",
                            subtitle: "Compose and manage commonly used payloads.",
                            systemImage: "doc.badge.gearshape"
                        )
                    }
                }
                .padding(16)
            }
            .navigationBarTitle("Tools")
        }
        .navigationViewStyle(StackNavigationViewStyle())
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

// MARK: - 4. Packet List View (The "Master" List)

private struct PacketListView: View {
    // Shared Data Source (Owned here for simplicity in this flow)
    @State private var templates: [PacketTemplate] = []
    private let dataManager = PacketDataManager()
    
    // Navigation State
    @State private var selectedPacketID: UUID?
    
    var body: some View {
        List {
            if templates.isEmpty {
                Text("No saved packets. Tap + to create.")
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }
            
            ForEach(templates) { template in
                NavigationLink(destination:
                    PacketEditorView(packet: template, onSave: { updatedPacket in
                        savePacket(updatedPacket)
                    }), tag: template.id, selection: $selectedPacketID
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name.isEmpty ? "New Packet" : template.name)
                            .font(.headline)
                            .foregroundColor(template.name.isEmpty ? .secondary : .primary)
                        
                        Text(template.payload.isEmpty ? "No Payload" : template.payload)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .fontDesign(.monospaced)
                        
                        Text(template.updatedAt, style: .date)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button {
                            copyToClipboard(template.payload)
                        } label: {
                            Label("Copy Payload", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            deleteTemplate(template.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onDelete { indexSet in
                delete(at: indexSet)
            }
        }
        .navigationBarTitle("Saved Packets")
        .navigationBarItems(trailing: Button(action: {
            createNewPacket()
        }) {
            Image(systemName: "square.and.pencil")
        })
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Logic
    
    private func loadData() {
        templates = dataManager.load()
    }
    
    private func createNewPacket() {
        let newPacket = PacketTemplate(id: UUID(), name: "", payload: "", updatedAt: Date())
        savePacket(newPacket)
        // Auto-select to navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedPacketID = newPacket.id
        }
    }
    
    private func savePacket(_ packet: PacketTemplate) {
        var current = templates
        if let index = current.firstIndex(where: { $0.id == packet.id }) {
            current[index] = packet
            current[index].updatedAt = Date()
        } else {
            current.insert(packet, at: 0)
        }
        
        _ = dataManager.save(current)
        templates = current
    }
    
    private func delete(at offsets: IndexSet) {
        var current = templates
        current.remove(atOffsets: offsets)
        _ = dataManager.save(current)
        templates = current
    }
    
    private func deleteTemplate(_ id: UUID) {
        var current = templates
        current.removeAll { $0.id == id }
        _ = dataManager.save(current)
        templates = current
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
    }
}

// MARK: - 5. Packet Editor View (The Detail)

private struct PacketEditorView: View {
    // Transient State for editing
    @State private var name: String
    @State private var payload: String
    
    let originalId: UUID
    let onSave: (PacketTemplate) -> Void
    
    init(packet: PacketTemplate, onSave: @escaping (PacketTemplate) -> Void) {
        self._name = State(initialValue: packet.name)
        self._payload = State(initialValue: packet.payload)
        self.originalId = packet.id
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Name
            VStack(alignment: .leading, spacing: 0) {
                NativeTextField(text: $name, placeholder: "Title")
                    .frame(height: 44)
                    .padding(.horizontal)
                
                Divider()
            }
            .background(Color(.systemBackground))
            
            // Payload Editor
            ZStack(alignment: .topLeading) {
                NativeTextView(text: $payload)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12) // NativeTextView padding
                
                if payload.isEmpty {
                    Text("Enter payload here...")
                        .foregroundColor(Color(.placeholderText))
                        .padding(.top, 8)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Auto-save on back
            let updated = PacketTemplate(id: originalId, name: name, payload: payload, updatedAt: Date())
            onSave(updated)
        }
    }
}
