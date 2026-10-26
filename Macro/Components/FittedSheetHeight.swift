//
//  FittedSheetHeight.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/21/26.
//

import SwiftUI
import UIKit

extension View {
    func fittedSheetHeight(_ height: CGFloat?) -> some View {
        background(FittedSheetHeightUpdater(height: height).frame(width: 0, height: 0))
    }
}

private struct FittedSheetHeightUpdater: UIViewControllerRepresentable {
    let height: CGFloat?

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.height = height
    }

    final class Controller: UIViewController {
        private static let detentID = UISheetPresentationController.Detent.Identifier("fittedHeight")
        private var appliedHeight: CGFloat?

        var height: CGFloat? {
            didSet { apply() }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        private func apply() {
            DispatchQueue.main.async { [weak self] in
                self?.applyNow()
            }
        }

        private func applyNow() {
            guard let height, height != appliedHeight, let sheet = sheetPresentationController else { return }
            appliedHeight = height
            sheet.animateChanges {
                sheet.detents = [.custom(identifier: Self.detentID) { _ in height }]
                sheet.selectedDetentIdentifier = Self.detentID
            }
        }
    }
}
