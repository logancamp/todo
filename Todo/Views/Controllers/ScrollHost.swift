//
//  TodoScrollHost.swift
//  Todo
//
//  Created by Logan Camp on 10/10/25.
//

import SwiftUI
import UIKit

private let draftID = "__draft__"

struct TodoScrollHost<Row: View, Header: View>: UIViewRepresentable {
    var sections: [TodoSection]
    var rowView: (Todo) -> Row
    var headerView: (TodoSection) -> Header

    var onCenteredSectionChange: (String) -> Void = { _ in }
    var onSelect: (String) -> Void = { _ in }
    var onDelete: (String) -> Void = { _ in }
    var onMove: (String, String?, String) -> Void = { _, _, _ in }

    var draftSectionID: String?
    var draftView: (() -> AnyView)?

    @Binding var collapse: CGFloat

    init(
        sections: [TodoSection],
        collapse: Binding<CGFloat>,
        onCenteredSectionChange: @escaping (String) -> Void = { _ in },
        onSelect: @escaping (String) -> Void = { _ in },
        onDelete: @escaping (String) -> Void = { _ in },
        onMove: @escaping (String, String?, String) -> Void = { _, _, _ in },
        draftSectionID: String? = nil,
        draftView: (() -> AnyView)? = nil,
        @ViewBuilder rowView: @escaping (Todo) -> Row,
        @ViewBuilder headerView: @escaping (TodoSection) -> Header
    ) {
        self.sections = sections
        self._collapse = collapse
        self.onCenteredSectionChange = onCenteredSectionChange
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onMove = onMove
        self.draftSectionID = draftSectionID
        self.draftView = draftView
        self.rowView = rowView
        self.headerView = headerView
    }

    func makeUIView(context: Context) -> UICollectionView {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: Layout.make())
        cv.backgroundColor = .clear
        cv.delegate = context.coordinator
        cv.delaysContentTouches = false
        cv.canCancelContentTouches = true
        cv.contentInset.bottom = UIScreen.main.bounds.height * 0.4

        context.coordinator.install(
            on: cv,
            rowView: { AnyView(rowView($0)) },
            headerView: { AnyView(headerView($0)) }
        )

        cv.dragDelegate = context.coordinator
        cv.dropDelegate = context.coordinator
        cv.dragInteractionEnabled = true

        DispatchQueue.main.async {
            cv.gestureRecognizers?
                .compactMap { $0 as? UILongPressGestureRecognizer }
                .forEach { $0.minimumPressDuration = 0.6 }
        }

        context.coordinator.apply(sections: sections, draftSectionID: draftSectionID, animated: false)
        return cv
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.onCenteredSectionChange = onCenteredSectionChange
        context.coordinator.onSelect = onSelect
        context.coordinator.onDelete = onDelete
        context.coordinator.onMove = onMove
        context.coordinator.collapse = $collapse
        context.coordinator.draftView = draftView
        context.coordinator.applyIfNeeded(sections: sections, draftSectionID: draftSectionID)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
}

// MARK: - Coordinator
// All three delegate conformances declared on the class itself.
// Extensions of nested classes in generic types cannot contain @objc members.

extension TodoScrollHost {
    final class Coordinator: NSObject,
        UICollectionViewDelegate,
        UICollectionViewDragDelegate,
        UICollectionViewDropDelegate
    {
        private(set) weak var collectionView: UICollectionView?
        private var dataSource: DS!
        private var lastFingerprint: Int = 0
        private var lastDraftSectionID: String? = nil

        var collapse: Binding<CGFloat> = .constant(0)
        var onCenteredSectionChange: (String) -> Void = { _ in }
        var onSelect: (String) -> Void = { _ in }
        var onDelete: (String) -> Void = { _ in }
        var onMove: (String, String?, String) -> Void = { _, _, _ in }
        var draftView: (() -> AnyView)?

        func install(
            on cv: UICollectionView,
            rowView: @escaping (Todo) -> AnyView,
            headerView: @escaping (TodoSection) -> AnyView
        ) {
            collectionView = cv
            dataSource = DS(collectionView: cv, rowView: rowView, headerView: headerView)
        }

        func apply(sections: [TodoSection], draftSectionID: String?, animated: Bool) {
            var snap = NSDiffableDataSourceSnapshot<String, String>()
            dataSource.setPayload(sections)
            dataSource.draftView = draftView

            for s in sections {
                snap.appendSections([s.id])
                var ids = s.items.map(\.id)
                if s.id == draftSectionID { ids.insert(draftID, at: 0) }
                snap.appendItems(ids, toSection: s.id)
            }

            let existing = Set(dataSource.snapshot().itemIdentifiers)
            let toReconfigure = sections.flatMap(\.items).map(\.id).filter { existing.contains($0) }
            if !toReconfigure.isEmpty { snap.reconfigureItems(toReconfigure) }

            dataSource.apply(snap, animatingDifferences: animated) { [weak self] in
                self?.updateCenteredSection()
            }
        }

        func applyIfNeeded(sections: [TodoSection], draftSectionID: String?) {
            let fp = fingerprint(sections, draftSectionID: draftSectionID)
            guard fp != lastFingerprint || draftSectionID != lastDraftSectionID else { return }
            lastFingerprint = fp
            lastDraftSectionID = draftSectionID
            apply(sections: sections, draftSectionID: draftSectionID, animated: true)
        }

        private func fingerprint(_ sections: [TodoSection], draftSectionID: String?) -> Int {
            var h = Hasher()
            h.combine(sections)
            h.combine(draftSectionID)
            return h.finalize()
        }

        // MARK: UICollectionViewDelegate — selection

        func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let id = dataSource.itemID(at: indexPath), id != draftID else { return }
            onSelect(id)
        }

        // MARK: UICollectionViewDelegate — swipe actions

        func collectionView(
            _ cv: UICollectionView,
            trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath
        ) -> UISwipeActionsConfiguration? {
            guard let id = dataSource.itemID(at: indexPath), id != draftID else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
                self?.onDelete(id); done(true)
            }
            let more = UIContextualAction(style: .normal, title: "More") { [weak self] _, _, done in
                self?.onSelect(id); done(true)
            }
            let config = UISwipeActionsConfiguration(actions: [delete, more])
            config.performsFirstActionWithFullSwipe = false
            return config
        }

        // MARK: UICollectionViewDelegate — scroll

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let p = max(0, min(1, scrollView.contentOffset.y / TodoLayout.headerMaxHeight))
            collapse.wrappedValue = p
            updateCenteredSection()
        }

        private func updateCenteredSection() {
            guard let cv = collectionView else { return }
            let centerY = cv.contentOffset.y + cv.bounds.height / 2
            let candidates = cv.indexPathsForVisibleItems
            guard !candidates.isEmpty else { return }
            let closest = candidates.min {
                let ay = cv.layoutAttributesForItem(at: $0)?.frame.midY ?? 0
                let by = cv.layoutAttributesForItem(at: $1)?.frame.midY ?? 0
                return abs(ay - centerY) < abs(by - centerY)
            }
            let idx = closest?.section ?? candidates.map(\.section).min() ?? 0
            if let sid = dataSource.sectionID(at: idx) { onCenteredSectionChange(sid) }
        }

        // MARK: UICollectionViewDragDelegate

        func collectionView(_ cv: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
            guard let id = dataSource.itemID(at: indexPath), id != draftID else { return [] }
            let provider = NSItemProvider(object: id as NSString)
            let dragItem = UIDragItem(itemProvider: provider)
            dragItem.localObject = id
            return [dragItem]
        }

        // MARK: UICollectionViewDropDelegate

        func collectionView(_ cv: UICollectionView, canHandle session: UIDropSession) -> Bool {
            session.localDragSession != nil
        }

        func collectionView(
            _ cv: UICollectionView,
            dropSessionDidUpdate session: UIDropSession,
            withDestinationIndexPath destPath: IndexPath?
        ) -> UICollectionViewDropProposal {
            guard session.localDragSession != nil else {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func collectionView(_ cv: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let item = coordinator.items.first,
                  let id = item.dragItem.localObject as? String,
                  id != draftID else { return }

            let destPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
            let sids = dataSource.snapshot().sectionIdentifiers
            guard destPath.section < sids.count else { return }

            let sectionID = sids[destPath.section]
            let itemsInSection = dataSource.snapshot()
                .itemIdentifiers(inSection: sectionID)
                .filter { $0 != draftID && $0 != id }

            let afterID: String? = destPath.item > 0 ? itemsInSection[safe: destPath.item - 1] : nil

            onMove(id, afterID, sectionID)
            coordinator.drop(item.dragItem, toItemAt: destPath)
        }
    }
}

// MARK: - Layout

private enum Layout {
    static func make() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = .init(top: 8, leading: 0, bottom: 24, trailing: 0)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize, elementKind: DS.headerKind, alignment: .top
        )
        header.pinToVisibleBounds = true
        header.zIndex = 2
        section.boundarySupplementaryItems = [header]

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 16
        return UICollectionViewCompositionalLayout(section: section, configuration: config)
    }
}

// MARK: - Reusable supplementary view

private final class SwiftUISupplementaryView: UICollectionReusableView {
    private var host: UIHostingController<AnyView>?

    func configure(with view: AnyView) {
        if let existing = host { existing.rootView = view }
        else {
            let hc = UIHostingController(rootView: view)
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hc.view)
            NSLayoutConstraint.activate([
                hc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
                hc.view.topAnchor.constraint(equalTo: topAnchor),
                hc.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            host = hc
        }
    }
}

// MARK: - Diffable data source

private final class DS: UICollectionViewDiffableDataSource<String, String> {
    static let headerKind = "todo.section.header"

    private var sectionsByID: [String: TodoSection] = [:]
    private var todosByID: [String: Todo] = [:]
    private var rowViewProvider: ((Todo) -> AnyView)?
    private var headerViewProvider: ((TodoSection) -> AnyView)?
    var draftView: (() -> AnyView)?

    init(
        collectionView: UICollectionView,
        rowView: @escaping (Todo) -> AnyView,
        headerView: @escaping (TodoSection) -> AnyView
    ) {
        let cellReg = UICollectionView.CellRegistration<UICollectionViewCell, String> { _, _, _ in }

        super.init(collectionView: collectionView) { cv, indexPath, id in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: id)
        }

        rowViewProvider = rowView
        headerViewProvider = headerView

        let headerReg = UICollectionView.SupplementaryRegistration<SwiftUISupplementaryView>(
            elementKind: Self.headerKind
        ) { [weak self] view, _, indexPath in
            guard let self,
                  let sid = self.snapshot().sectionIdentifiers[safe: indexPath.section],
                  let section = self.sectionsByID[sid],
                  let hv = self.headerViewProvider else { return }
            view.configure(with: hv(section))
        }

        supplementaryViewProvider = { cv, _, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    override func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(cv, cellForItemAt: indexPath)
        guard let id = itemIdentifier(for: indexPath) else { return cell }

        if id == draftID {
            if let dv = draftView {
                cell.contentConfiguration = UIHostingConfiguration { dv() }.margins(.all, 0)
            }
        } else if let todo = todosByID[id], let rv = rowViewProvider {
            cell.contentConfiguration = UIHostingConfiguration { rv(todo) }.margins(.all, 0)
        }
        return cell
    }

    func setPayload(_ sections: [TodoSection]) {
        sectionsByID = sections.reduce(into: [:]) { $0[$1.id] = $1 }
        todosByID = sections.flatMap(\.items).reduce(into: [:]) { $0[$1.id] = $1 }
    }

    func sectionID(at index: Int) -> String? { snapshot().sectionIdentifiers[safe: index] }

    func itemID(at indexPath: IndexPath) -> String? {
        let sids = snapshot().sectionIdentifiers
        guard indexPath.section < sids.count else { return nil }
        let iids = snapshot().itemIdentifiers(inSection: sids[indexPath.section])
        guard indexPath.item < iids.count else { return nil }
        return iids[indexPath.item]
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
