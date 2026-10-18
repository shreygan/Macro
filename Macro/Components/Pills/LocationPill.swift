//
//  LocationPill.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import SwiftUI

struct LocationPill: View {
    var selection: LocationSelection
    var showsPermissionPrompt: Bool = false
    var isEnabled: Bool = true
    var isHere: Bool = false
    var action: () -> Void
    var onShowOnMap: (() -> Void)? = nil
    var onOpenInMaps: (() -> Void)? = nil

    private var showsMapMenu: Bool {
        !isEnabled && (onShowOnMap != nil || onOpenInMaps != nil)
    }

    private var showsLocationSymbol: Bool {
        selection.isCurrent || isHere
    }

    private var symbol: String? {
        guard isEnabled else { return nil }
        if showsLocationSymbol { return "location.fill" }
        if showsPermissionPrompt { return "exclamationmark.circle" }
        return nil
    }

    private var text: String {
        switch selection {
        case .current:
            // Once it has landed somewhere, the pill names the place and leaves the arrow to say
            // it was found for you. Only a fix with nothing to call it falls back to the mode.
            return selection.currentPlaceName ?? String(localized: "Current Location")
        case .place(let location):
            return location.name
        case .none:
            return showsPermissionPrompt && isEnabled
                ? String(localized: "Enable Location") : "-"
        }
    }

    private var isPlaceholder: Bool {
        selection.isNone && !(showsPermissionPrompt && isEnabled)
    }

    var body: some View {
        Group {
            if showsMapMenu {
                ZStack {
                    label
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    Menu {
                        mapMenuContent
                    } label: {
                        label
                            .opacity(0.011)
                    }
                    .menuStyle(.button)
                }
            } else {
                Button(action: action) {
                    label
                }
                .disabled(!isEnabled)
            }
        }
        .buttonStyle(UndimmedPlainButtonStyle())
        .animation(.snappy(duration: 0.3), value: isEnabled)
        .animation(.snappy(duration: 0.3), value: selection)
        .animation(.snappy(duration: 0.3), value: isHere)
        .accessibilityLabel("Location")
        .accessibilityValue(text)
    }

    private var label: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.smallIcon)
                    .foregroundStyle(showsLocationSymbol ? Color.accentColor : Color.orange)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            Text(text)
                .underline(showsMapMenu, pattern: .dot)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(
                    !isEnabled || isPlaceholder ? Color.secondary : Color.primary
                )
        }
        .pillBackground(isEnabled: isEnabled)
    }

    @ViewBuilder
    private var mapMenuContent: some View {
        if let onShowOnMap {
            Button("Show on Map", systemImage: "map", action: onShowOnMap)
        }

        if let onOpenInMaps {
            Button("Open in Maps", systemImage: "arrow.up.forward.app", action: onOpenInMaps)
        }
    }
}

private struct UndimmedPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#Preview {
    ZStack {
        Color.background.ignoresSafeArea()

        Card {
            RowGroup(.divider) {
                BaseRowLayout(title: "Location", fitsRightContent: true) {
                    LocationPill(selection: .current(nil)) {}
                }
                BaseRowLayout(title: "Location", fitsRightContent: true) {
                    LocationPill(
                        selection: .place(EntryLocation(name: "French Immersion School of Washington"))
                    ) {}
                }
                BaseRowLayout(title: "Location", fitsRightContent: true) {
                    LocationPill(
                        selection: .place(EntryLocation(name: "Chipotle Mexican Grill Downtown"))
                    ) {}
                }
                BaseRowLayout(title: "Location", fitsRightContent: true) {
                    LocationPill(selection: .none, showsPermissionPrompt: true) {}
                }
                BaseRowLayout(title: "Location", fitsRightContent: true) {
                    LocationPill(selection: .none) {}
                }
                BaseRowLayout(title: "Location", fitsRightContent: true) {
                    LocationPill(
                        selection: .place(EntryLocation(name: "Home")),
                        isEnabled: false
                    ) {}
                }
            }
        }
        .padding()
    }
}
