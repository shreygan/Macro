//
//  LeaveObserver.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/15/26.
//

import SwiftUI
import UIKit

private final class LeaveObserverController: UIViewController {
    var onLeave: () -> Void = {}

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let coordinator = transitionCoordinator,
            let destination = coordinator.viewController(forKey: .to),
            !destination.isBeingPresented,
            !destination.isMovingToParent
        else { return }

        if coordinator.isInteractive {
            coordinator.notifyWhenInteractionChanges { [weak self] context in
                guard !context.isCancelled else { return }
                self?.onLeave()
            }
        } else {
            onLeave()
        }
    }
}

private struct LeaveObserver: UIViewControllerRepresentable {
    let onLeave: () -> Void

    func makeUIViewController(context: Context) -> LeaveObserverController {
        let controller = LeaveObserverController()
        controller.view.isUserInteractionEnabled = false
        controller.onLeave = onLeave
        return controller
    }

    func updateUIViewController(_ controller: LeaveObserverController, context: Context) {
        controller.onLeave = onLeave
    }
}

extension View {
    func onLeave(perform action: @escaping () -> Void) -> some View {
        background(LeaveObserver(onLeave: action).frame(width: 0, height: 0))
    }
}
