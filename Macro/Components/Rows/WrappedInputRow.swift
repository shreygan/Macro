//
//  WrappedInputRow.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-11.
//

import SwiftUI

struct WrappedInputRow: View {
    var placeholder: String
    @Binding var text: String
    var caption: String? = nil
    var captionSymbol: String? = nil
    var captionTint: Color = .secondary
    var keyboardType: UIKeyboardType = .default

    var isEditable: Bool = true

    var characterLimit: Int? = nil
    var topPadding: CGFloat = 14
    var bottomPadding: CGFloat = 14
    var focusOnAppear: Bool = false
    var onFocusChange: ((Bool) -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var selection: TextSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditable {
                TextField(
                    placeholder,
                    text: $draft,
                    selection: $selection,
                    axis: .vertical
                )
                    .focused($isFocused)
                    .autoFloatingToolbar(
                        for: keyboardType,
                        text: $text,
                        draft: $draft,
                        selection: $selection
                    )
                    .lineLimit(1...10)
                    .numericKeyboardFilter(text: $draft, type: keyboardType)
                    .textInputAutocapitalization(.never)
                    .onChange(of: text) { oldValue, newValue in
                        if let limit = characterLimit, newValue.count > limit {
                            text = String(newValue.prefix(limit))
                        }
                    }
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundColor(
                        text.isEmpty
                            ? .secondary.opacity(0.5)
                            : Color(uiColor: .secondaryLabel)
                    )
                    .lineLimit(nil)
                    .frame(minHeight: 22, alignment: .topLeading)
            }

            if caption != nil || captionSymbol != nil {
                HStack(spacing: 4) {
                    if let captionSymbol {
                        Image(systemName: captionSymbol)
                            .foregroundStyle(captionTint)
                    }
                    if let caption {
                        Text(caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isEditable, let limit = characterLimit {
                let threshold = Int(Double(limit) * 0.75)

                if text.count > threshold {
                    Text("\(text.count)/\(limit)")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(
                            text.count >= limit ? .red : .secondary
                        )
                        .offset(y: 11)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            if focusOnAppear && isEditable {
                isFocused = true
            }
        }
        .onChange(of: isFocused) { _, focused in
            onFocusChange?(focused)
        }
    }
}

#Preview {
    @Previewable @State var newNoteText = "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec pede justo, fringilla vel, aliquet nec, vulputate eget, arcu. In enim justo, rhoncus ut, imperdiet a, venenatis vitae, justo. Nullam dictum felis eu pede mollis pretium. Integer tincidunt. Cras dapibus. Vivamus elementum semper nisi. Aenean vulputate eleifend tellus. Aenean leo ligula, porttitor eu, consequat vitae, eleifend ac, enim. Aliquam lorem ante, dapibus in, viverra quis, feugiat a, tellus. Phasellus viverra nulla ut metus varius laoreet. Quisque rutrum. Aenean imperdiet. Etiam ultricies nisi vel augue. Curabitur ullamcorper ultricies nisi. Nam eget dui. Etiam rhoncus. Maecenas tempus, tellus eget condimentum rhoncus, sem quam semper libero, sit amet adipiscing sem neque sed ipsum. Nam quam nunc, blandit vel, luctus pulvinar, hendrerit id, lorem. Maecenas nec odio et ante tincidunt tempus. Donec vitae sapien ut libero venenatis faucibus. Nullam quis ante. Etiam sit amet orci eget eros faucibus tincidunt. Duis leo. Sed fringilla mauris sit amet nibh. Donec sodales sagittis magna. Sed consequat, leo eget bibendum sodales, augue velit cursus nunc, quis gravida magna mi a libero. Fusce vulputate eleifend sapien. Vestibulum purus quam, scelerisque ut, mollis sed, nonummy id, metus. Nullam accumsan lorem in dui. Cras ultricies mi eu turpis hendrerit fringilla. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; In ac dui quis mi consectetuer lacinia. Nam pretium turpis et arcu. Duis arcu tortor, suscipit eget, imperdiet nec, imperdiet iaculis, ipsum. Sed aliquam ultrices mauris. Integer ante arcu, accumsan a, consectetuer eget, posuere ut, mauris. Praesent adipiscing. Phasellus ullamcorper ipsum rutrum nunc. Nunc nonummy metus. Vesti"
    @Previewable @State var editingNoteText =
        "This is a note that I am currently editing inline."

    ZStack {
        Color.background.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("NEW ENTRY NOTE")
                        .font(.caption).bold().foregroundColor(.secondary)
                        .padding(.horizontal)

                    Card {
                        WrappedInputRow(
                            placeholder: "Add a note...",
                            text: $newNoteText,
                            isEditable: true,
                            characterLimit: 2000
                        )
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("PINNED NOTE")
                        .font(.caption).bold().foregroundColor(.secondary)
                        .padding(.horizontal)

                    Card {
                        WrappedInputRow(
                            placeholder: "Add a pinned note...",
                            text: $editingNoteText,
                            caption: "Updated 2 days ago",
                            captionSymbol: "pin.fill",
                            captionTint: .orange
                        )
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("READ ONLY")
                        .font(.caption).bold().foregroundColor(.secondary)
                        .padding(.horizontal)

                    Card {
                        WrappedInputRow(
                            placeholder: "Add a note...",
                            text: .constant(
                                "Tasted amazing. Added an extra scoop of protein."
                            ),
                            isEditable: false
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}
