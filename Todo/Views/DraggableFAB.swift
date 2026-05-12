//
//  DraggableFAB.swift
//  Todo
//
//  Created by Logan Camp on 5/11/26.
//


import SwiftUI
import UIKit

private let fabNewItemID = "__fab_new__"

/// A floating action button implemented as a UIViewRepresentable so it can
/// use a native UIDragInteraction — SwiftUI's .onDrag conflicts with the
/// UIHostingController wrapper and causes _UIPlatterView hierarchy warnings.
struct DraggableFAB: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let size: CGFloat = 56

        // Outer container carries the shadow and drag interaction
        let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowRadius = 8
        container.layer.shadowOpacity = 0.25
        container.layer.shadowOffset = .zero

        // Blur background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.frame = container.bounds
        blur.layer.cornerRadius = size / 2
        blur.clipsToBounds = true
        container.addSubview(blur)

        // Plus button inside blur
        let button = UIButton(type: .system)
        let imgConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        button.setImage(UIImage(systemName: "plus", withConfiguration: imgConfig), for: .normal)
        button.tintColor = .label
        button.frame = blur.bounds
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        blur.contentView.addSubview(button)

        // Native drag interaction — creates a UIDragItem with localObject = fabNewItemID
        // so ScrollHost can reliably detect FAB drops without async item provider loading
        let drag = UIDragInteraction(delegate: context.coordinator)
        drag.isEnabled = true
        container.addInteraction(drag)

        context.coordinator.container = container
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIDragInteractionDelegate {
        var onTap: () -> Void
        weak var container: UIView?

        init(onTap: @escaping () -> Void) { self.onTap = onTap }

        @objc func tapped() { onTap() }

        // Provide a drag item with localObject set so performDropWith can
        // identify it instantly without any async loading
        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            let provider = NSItemProvider(object: fabNewItemID as NSString)
            let item = UIDragItem(itemProvider: provider)
            item.localObject = fabNewItemID
            return [item]
        }

        // Round preview matching the button shape
        func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
            guard let view = container else { return nil }
            let params = UIDragPreviewParameters()
            params.visiblePath = UIBezierPath(ovalIn: view.bounds)
            params.backgroundColor = .clear
            let target = UIDragPreviewTarget(container: view, center: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
            return UITargetedDragPreview(view: view, parameters: params, target: target)
        }
    }
}

/// The sentinel value carried by DraggableFAB drag items.
/// Used by ScrollHost to identify FAB drops in performDropWith.
let fabNewItemMarker = fabNewItemID
