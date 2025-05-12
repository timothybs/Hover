//
//  SceneDelegate.swift
//  Hover
//
//  Created by Timothy Sumner on 12/05/2025.
//


import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = PortraitHostingController(rootView: HoverAppRootView())
        self.window = window
        window.makeKeyAndVisible()
    }
}