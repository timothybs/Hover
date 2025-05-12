//
//  PortraitHostingController.swift
//  Hover
//
//  Created by Timothy Sumner on 12/05/2025.
//


import SwiftUI

class PortraitHostingController<Content>: UIHostingController<Content> where Content: View {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}