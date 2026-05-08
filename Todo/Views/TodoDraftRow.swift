//
//  TodoDraftRow.swift
//  Todo
//
//  Created by Logan Camp on 5/8/26.
//

import SwiftUI

struct TodoDraftRow: View {
    @Binding var title: String
    @Binding var notes: String
    @Binding var kind: TodoKind
    @Binding var dueDate: Date?

    var onSave: () -> Void
    var onCancel: () -> Void

    @FocusState private var focus: Field?
    @State private var showDatePicker = false

    private enum Field { case title, notes }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Circle + title + notes in line with item rows
            HStack(spacing: 0) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    TextField("New todo", text: $title)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focus = .notes }

                    TextField("Notes", text: $notes)
                        .focused($focus, equals: .notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .submitLabel(.done)
                        .onSubmit { commit() }
                }
                .padding(.trailing, 16)
            }

            // Bottom toolbar
            HStack(spacing: 12) {
                // Kind picker
                Menu {
                    ForEach(TodoKind.allCases) { k in
                        Button { kind = k } label: {
                            Label(k.rawValue.capitalized, systemImage: kindIcon(k))
                        }
                    }
                } label: {
                    DraftBadge(kind: kind)
                }

                // Due date
                Button {
                    withAnimation(.snappy) { showDatePicker.toggle() }
                } label: {
                    Label(
                        dueDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Date",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(dueDate != nil ? .blue : .secondary)
                }

                if dueDate != nil {
                    Button {
                        dueDate = nil
                        showDatePicker = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Cancel") { onCancel() }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Save") { commit() }
                    .font(.caption.bold())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.leading, 44)

            if showDatePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0; showDatePicker = false }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.leading, 44)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .animation(.snappy, value: showDatePicker)
        .onAppear { focus = .title }
        // Auto-save when view disappears (keyboard dismissed)
        .onDisappear { commit() }
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { onCancel() } else { onSave() }
    }

    private func kindIcon(_ k: TodoKind) -> String {
        switch k {
        case .task:      return "checkmark.circle"
        case .reminder:  return "bell"
        case .checklist: return "list.bullet"
        }
    }
}

private struct DraftBadge: View {
    let kind: TodoKind
    var body: some View {
        Text(kind.rawValue)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        switch kind {
        case .task:      .blue
        case .reminder:  .orange
        case .checklist: .purple
        }
    }
}
