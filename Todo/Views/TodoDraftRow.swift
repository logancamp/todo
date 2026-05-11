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
    @Binding var scheduledFor: Date?
    @Binding var dueAt: Date?

    var onSave: () -> Void
    var onCancel: () -> Void

    @FocusState private var focus: Field?
    @State private var showSchedulePicker = false
    @State private var showDuePicker = false

    private enum Field { case title, notes }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("New todo", text: $title)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focus = .notes }

                    // Notes — grows with content
                    TextEditor(text: $notes)
                        .frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .scrollDisabled(true)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .padding(.trailing, 16)
            }

            // Toolbar
            HStack(spacing: 12) {
                Menu {
                    ForEach(TodoKind.allCases) { k in
                        Button { kind = k } label: {
                            Label(k.rawValue.capitalized, systemImage: kindIcon(k))
                        }
                    }
                } label: {
                    DraftKindBadge(kind: kind)
                }

                // Schedule date
                Button {
                    showSchedulePicker.toggle()
                    showDuePicker = false
                } label: {
                    Label(
                        scheduledFor?.formatted(date: .abbreviated, time: .omitted) ?? "Set date",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(scheduledFor != nil ? .blue : .secondary)
                }
                if scheduledFor != nil {
                    Button { scheduledFor = nil; showSchedulePicker = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Due date
                Button {
                    showDuePicker.toggle()
                    showSchedulePicker = false
                } label: {
                    Label(
                        dueAt?.formatted(date: .abbreviated, time: .omitted) ?? "Due date",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(dueAt != nil ? .orange : .secondary)
                }
                if dueAt != nil {
                    Button { dueAt = nil; showDuePicker = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 44)

            if showSchedulePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { scheduledFor ?? Date() },
                        set: { scheduledFor = $0; showSchedulePicker = false }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.leading, 44)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showDuePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dueAt ?? Date() },
                        set: { dueAt = $0; showDuePicker = false }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.leading, 44)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .animation(.snappy, value: showSchedulePicker)
        .animation(.snappy, value: showDuePicker)
        .onAppear { focus = .title }
        .onDisappear { commit() }  // auto-save when tapped off
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

private struct DraftKindBadge: View {
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

