//
//  PresentationWaiter.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/17/26.
//

import UIKit

@MainActor
enum PresentationWaiter {
    static func topPresentedController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    static func waitForPresentation(
        over presenter: UIViewController?,
        while isPending: () -> Bool,
        timeout: Duration = .seconds(10)
    ) async {
        let deadline = ContinuousClock.now + timeout
        while isPending(), ContinuousClock.now < deadline {
            if topPresentedController() !== presenter { return }
            try? await Task.sleep(for: .milliseconds(30))
        }
    }
}
