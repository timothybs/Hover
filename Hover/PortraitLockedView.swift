//
//  PortraitLockedView.swift
//  Hover
//
//  Created by Timothy Sumner on 11/05/2025.
//

import SwiftUI
import UIKit

struct PortraitLockedView<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let hosting = UIHostingController(rootView: content)
        return PortraitEnforcingViewController(rootController: hosting)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private class PortraitEnforcingViewController: UIViewController {
    let rootController: UIViewController

    init(rootController: UIViewController) {
        self.rootController = rootController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(rootController)
        view.addSubview(rootController.view)
        rootController.view.frame = view.bounds
        rootController.didMove(toParent: self)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
