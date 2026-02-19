//
//  EntryView.swift
//  BragLog
//

import SwiftUI

struct EntryView: View {
    @ObservedObject var viewModel: EntryViewModel
    @State private var tagFilterText: String = ""
    @FocusState private var messageFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $viewModel.message)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor)) 
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                .overlay(Group {
                    if viewModel.message.isEmpty {
                        Text("Main log entry")
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.top, 1)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }, alignment: .topLeading)
                .focused($messageFocused)

            TagsFieldView(
                selectedTags: $viewModel.selectedTags,
                allTags: viewModel.allTags,
                filterText: $tagFilterText
            )


            if let error = viewModel.saveError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Save") {
                    viewModel.save()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!viewModel.canSave)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .frame(width: 400)
        .onAppear {
            viewModel.loadTags()
            messageFocused = true
        }
        .onDisappear {
            tagFilterText = ""
            viewModel.saveError = nil
        }
        .onChange(of: viewModel.shouldClosePopover) { _, shouldClose in
            if shouldClose {
                tagFilterText = ""
            }
        }
    }
}

#Preview {
    EntryView(viewModel: EntryViewModel(database: try! DatabaseService(dbPath: ":memory:")))
        .frame(width: 400)
}
