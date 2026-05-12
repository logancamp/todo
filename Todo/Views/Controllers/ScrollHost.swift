//
//  TodoScrollHost.swift
//  Todo
//
//  Created by Logan Camp on 10/10/25.
//

import SwiftUI
import UIKit

private let detailPrefix = "__detail__"

private func detailItemID(_ id: String) -> String { "\(detailPrefix)\(id)" }
private func todoIDFromDetail(_ id: String) -> String? {
    id.hasPrefix(detailPrefix) ? String(id.dropFirst(detailPrefix.count)) : nil
}

private final class TodoCollectionView: UICollectionView {
    override func layoutSubviews() {
        UIView.performWithoutAnimation { super.layoutSubviews() }
    }
}

// MARK: - Public SwiftUI wrapper

struct TodoScrollHost<Row: View, Header: View>: UIViewRepresentable {
    var sections: [TodoSection]
    var rowView: (Todo) -> Row
    var headerView: (TodoSection) -> Header

    var expandedTodoID: Todo.ID? = nil
    var onCenteredSectionChange: (String) -> Void = { _ in }
    var onSelect: (String) -> Void = { _ in }
    var onDelete: (String) -> Void = { _ in }
    var onMove: (String, String?, String?, String) -> Void = { _, _, _, _ in }
    var onBackgroundTap: () -> Void = { }
    var onNewItemDrop: (String, String?, String?) -> Void = { _, _, _ in }
    var detailView: ((Todo) -> AnyView)? = nil

    @Binding var collapse: CGFloat

    init(
        sections: [TodoSection],
        collapse: Binding<CGFloat>,
        expandedTodoID: Todo.ID? = nil,
        onCenteredSectionChange: @escaping (String) -> Void = { _ in },
        onSelect: @escaping (String) -> Void = { _ in },
        onDelete: @escaping (String) -> Void = { _ in },
        onMove: @escaping (String, String?, String?, String) -> Void = { _, _, _, _ in },
        onBackgroundTap: @escaping () -> Void = { },
        onNewItemDrop: @escaping (String, String?, String?) -> Void = { _, _, _ in },
        detailView: ((Todo) -> AnyView)? = nil,
        @ViewBuilder rowView: @escaping (Todo) -> Row,
        @ViewBuilder headerView: @escaping (TodoSection) -> Header
    ) {
        self.sections = sections
        self._collapse = collapse
        self.expandedTodoID = expandedTodoID
        self.onCenteredSectionChange = onCenteredSectionChange
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onMove = onMove
        self.onBackgroundTap = onBackgroundTap
        self.onNewItemDrop = onNewItemDrop
        self.detailView = detailView
        self.rowView = rowView
        self.headerView = headerView
    }

    func makeUIView(context: Context) -> UICollectionView {
        let cv = TodoCollectionView(frame: .zero, collectionViewLayout: CollectionLayout.make())
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

        let bgTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleBackgroundTap(_:)))
        bgTap.cancelsTouchesInView = false
        cv.addGestureRecognizer(bgTap)

        DispatchQueue.main.async {
            cv.gestureRecognizers?
                .compactMap { $0 as? UILongPressGestureRecognizer }
                .forEach { $0.minimumPressDuration = 0.35 }
        }

        context.coordinator.applySnapshot(sections: sections, expandedTodoID: expandedTodoID, animated: false)
        return cv
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.onCenteredSectionChange = onCenteredSectionChange
        context.coordinator.onSelect = onSelect
        context.coordinator.onDelete = onDelete
        context.coordinator.onMove = onMove
        context.coordinator.onBackgroundTap = onBackgroundTap
        context.coordinator.onNewItemDrop = onNewItemDrop
        context.coordinator.collapse = $collapse
        context.coordinator.detailView = detailView
        context.coordinator.updateRowView { AnyView(rowView($0)) }
        context.coordinator.applySnapshotIfNeeded(sections: sections, expandedTodoID: expandedTodoID)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
}

// MARK: - Coordinator

extension TodoScrollHost {
    final class Coordinator: NSObject,
        UICollectionViewDelegate,
        UICollectionViewDragDelegate,
        UICollectionViewDropDelegate
    {
        private weak var collectionView: UICollectionView?
        private var dataSource: SectionDataSource!
        private var lastFingerprint: Int = 0
        private var isDragging = false
        private var lastDragEndTime: Date = .distantPast
        private var pendingSections: [TodoSection] = []
        private var pendingExpandedTodoID: Todo.ID? = nil

        var collapse: Binding<CGFloat> = .constant(0)
        var onCenteredSectionChange: (String) -> Void = { _ in }
        var onSelect: (String) -> Void = { _ in }
        var onDelete: (String) -> Void = { _ in }
        var onMove: (String, String?, String?, String) -> Void = { _, _, _, _ in }
        var onBackgroundTap: () -> Void = { }
        var onNewItemDrop: (String, String?, String?) -> Void = { _, _, _ in }
        var detailView: ((Todo) -> AnyView)?

        func install(
            on cv: UICollectionView,
            rowView: @escaping (Todo) -> AnyView,
            headerView: @escaping (TodoSection) -> AnyView
        ) {
            collectionView = cv
            dataSource = SectionDataSource(collectionView: cv, rowView: rowView, headerView: headerView)
        }

        func updateRowView(_ rowView: @escaping (Todo) -> AnyView) {
            dataSource.rowViewProvider = rowView
        }

        func applySnapshot(sections: [TodoSection], expandedTodoID: Todo.ID?, animated: Bool) {
            var snap = NSDiffableDataSourceSnapshot<String, String>()
            dataSource.setPayload(sections)
            dataSource.detailView = detailView

            for s in sections {
                snap.appendSections([s.id])
                var ids = s.items.map(\.id)
                if let eid = expandedTodoID, let idx = ids.firstIndex(of: eid) {
                    ids.insert(detailItemID(eid), at: idx + 1)
                }
                snap.appendItems(ids, toSection: s.id)
            }

            let existingIDs = Set(dataSource.snapshot().itemIdentifiers)
            let changed = sections.flatMap(\.items).map(\.id).filter { existingIDs.contains($0) }
            if !changed.isEmpty { snap.reconfigureItems(changed) }

            dataSource.apply(snap, animatingDifferences: animated) { [weak self] in
                self?.updateCenteredSection()
            }
        }

        func applySnapshotIfNeeded(sections: [TodoSection], expandedTodoID: Todo.ID?) {
            if isDragging {
                pendingSections = sections
                pendingExpandedTodoID = expandedTodoID
                return
            }

            let fp = fingerprint(sections, expandedTodoID: expandedTodoID)
            guard fp != lastFingerprint else {
                dataSource.detailView = detailView
                var snap = dataSource.snapshot()
                let allIDs = snap.itemIdentifiers.filter { !$0.hasPrefix(detailPrefix) }
                if !allIDs.isEmpty {
                    snap.reconfigureItems(allIDs)
                    dataSource.apply(snap, animatingDifferences: false)
                }
                return
            }

            lastFingerprint = fp

            let incomingIDs = sections.flatMap(\.items).map(\.id)
            let currentIDs = dataSource.snapshot().itemIdentifiers.filter { !$0.hasPrefix(detailPrefix) }
            let orderChanged = incomingIDs != currentIDs

            if orderChanged {
                let animate = Date().timeIntervalSince(lastDragEndTime) > 1.0
                applySnapshot(sections: sections, expandedTodoID: expandedTodoID, animated: animate)
            } else {
                dataSource.setPayload(sections)
                dataSource.detailView = detailView
                var snap = dataSource.snapshot()

                let toReconfigure = sections.flatMap(\.items).map(\.id)
                    .filter { snap.itemIdentifiers.contains($0) }
                if !toReconfigure.isEmpty { snap.reconfigureItems(toReconfigure) }

                let currentDetailItems = snap.itemIdentifiers.filter { $0.hasPrefix(detailPrefix) }
                let wantedDetailID = expandedTodoID.map { detailItemID($0) }
                for existing in currentDetailItems where existing != wantedDetailID {
                    snap.deleteItems([existing])
                }
                if let wanted = wantedDetailID, !snap.itemIdentifiers.contains(wanted),
                   let todoID = expandedTodoID, snap.itemIdentifiers.contains(todoID) {
                    snap.insertItems([wanted], afterItem: todoID)
                }
                dataSource.apply(snap, animatingDifferences: true)
            }
        }

        private func fingerprint(_ sections: [TodoSection], expandedTodoID: Todo.ID?) -> Int {
            var h = Hasher()
            h.combine(sections)
            h.combine(expandedTodoID)
            return h.finalize()
        }

        @objc func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
            guard let cv = collectionView else { return }
            let location = gesture.location(in: cv)
            if cv.indexPathForItem(at: location) == nil { onBackgroundTap() }
        }

        // MARK: UICollectionViewDelegate

        func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let id = dataSource.itemID(at: indexPath),
                  !id.hasPrefix(detailPrefix) else { return }
            onSelect(id)
        }

        func collectionView(
            _ cv: UICollectionView,
            trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath
        ) -> UISwipeActionsConfiguration? {
            guard let id = dataSource.itemID(at: indexPath),
                  !id.hasPrefix(detailPrefix) else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
                self?.onDelete(id); done(true)
            }
            let config = UISwipeActionsConfiguration(actions: [delete])
            config.performsFirstActionWithFullSwipe = true
            return config
        }

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
                abs((cv.layoutAttributesForItem(at: $0)?.frame.midY ?? 0) - centerY) <
                abs((cv.layoutAttributesForItem(at: $1)?.frame.midY ?? 0) - centerY)
            }
            let idx = closest?.section ?? candidates.map(\.section).min() ?? 0
            if let sid = dataSource.sectionID(at: idx) { onCenteredSectionChange(sid) }
        }

        // MARK: UICollectionViewDragDelegate

        func collectionView(_ cv: UICollectionView, dragSessionWillBegin session: UIDragSession) {
            isDragging = true
        }

        func collectionView(_ cv: UICollectionView, dragSessionDidEnd session: UIDragSession) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.lastDragEndTime = Date()
                self.isDragging = false
                let sections = self.pendingSections
                let expandedTodoID = self.pendingExpandedTodoID
                guard !sections.isEmpty else { return }
                self.lastFingerprint = self.fingerprint(sections, expandedTodoID: expandedTodoID)
                self.pendingSections = []
                self.pendingExpandedTodoID = nil
                self.applySnapshot(sections: sections, expandedTodoID: expandedTodoID, animated: false)
            }
        }

        func collectionView(_ cv: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
            guard let id = dataSource.itemID(at: indexPath),
                  !id.hasPrefix(detailPrefix) else { return [] }
            let provider = NSItemProvider(object: id as NSString)
            let dragItem = UIDragItem(itemProvider: provider)
            dragItem.localObject = id
            return [dragItem]
        }

        // MARK: UICollectionViewDropDelegate

        func collectionView(_ cv: UICollectionView, canHandle session: UIDropSession) -> Bool {
            // Accept internal reorders and FAB drags (both are local sessions)
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
            let isFABDrag = session.localDragSession?.items.first?.localObject as? String == fabNewItemMarker
            return UICollectionViewDropProposal(
                operation: isFABDrag ? .copy : .move,
                intent: .insertAtDestinationIndexPath
            )
        }

        func collectionView(_ cv: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let item = coordinator.items.first else { return }

            let destPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
            let sectionIDs = dataSource.snapshot().sectionIdentifiers
            guard destPath.section < sectionIDs.count else { return }
            let sectionID = sectionIDs[destPath.section]

            // FAB drop — localObject is fabNewItemMarker
            if item.dragItem.localObject as? String == fabNewItemMarker {
                let peers = dataSource.snapshot()
                    .itemIdentifiers(inSection: sectionID)
                    .filter { !$0.hasPrefix(detailPrefix) }
                let afterID: String? = destPath.item > 0 ? peers[safe: destPath.item - 1] : nil
                let beforeID: String? = peers[safe: destPath.item]
                onNewItemDrop(sectionID, afterID, beforeID)
                return
            }

            // Internal reorder
            guard let id = item.dragItem.localObject as? String else { return }

            let peers = dataSource.snapshot()
                .itemIdentifiers(inSection: sectionID)
                .filter { !$0.hasPrefix(detailPrefix) && $0 != id }

            let afterID: String? = destPath.item > 0 ? peers[safe: destPath.item - 1] : nil
            let beforeID: String? = peers[safe: destPath.item]

            var snap = dataSource.snapshot()
            snap.deleteItems([id])
            if let afterID {
                snap.insertItems([id], afterItem: afterID)
            } else {
                let remaining = snap.itemIdentifiers(inSection: sectionID).filter { !$0.hasPrefix(detailPrefix) }
                if let first = remaining.first { snap.insertItems([id], beforeItem: first) }
                else { snap.appendItems([id], toSection: sectionID) }
            }
            dataSource.apply(snap, animatingDifferences: false)

            var landingPath = destPath
            let updatedSnap = dataSource.snapshot()
            outer: for (sIdx, sid) in updatedSnap.sectionIdentifiers.enumerated() {
                for (iIdx, itemID) in updatedSnap.itemIdentifiers(inSection: sid).enumerated() {
                    if itemID == id { landingPath = IndexPath(item: iIdx, section: sIdx); break outer }
                }
            }

            coordinator.drop(item.dragItem, toItemAt: landingPath)
            onMove(id, afterID, beforeID, sectionID)
        }
    }
}

// MARK: - Layout

private enum CollectionLayout {
    static func make() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0
        section.contentInsets = .init(top: 8, leading: 0, bottom: 24, trailing: 0)
        section.visibleItemsInvalidationHandler = { _, _, _ in }

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize, elementKind: SectionDataSource.headerElementKind, alignment: .top
        )
        header.pinToVisibleBounds = true
        header.zIndex = 2
        section.boundarySupplementaryItems = [header]

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 16
        return UICollectionViewCompositionalLayout(section: section, configuration: config)
    }
}

private final class SectionHeaderView: UICollectionReusableView {
    private var hostingController: UIHostingController<AnyView>?
    func configure(with view: AnyView) {
        if let existing = hostingController { existing.rootView = view }
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
            hostingController = hc
        }
    }
}

private final class TodoCell: UICollectionViewCell {
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        UIView.performWithoutAnimation { super.apply(layoutAttributes) }
    }
}

private final class SectionDataSource: UICollectionViewDiffableDataSource<String, String> {
    static let headerElementKind = "todo.section.header"
    private var sectionsByID: [String: TodoSection] = [:]
    private var todosByID: [String: Todo] = [:]
    var rowViewProvider: ((Todo) -> AnyView)?
    private var headerViewProvider: ((TodoSection) -> AnyView)?
    var detailView: ((Todo) -> AnyView)?

    init(
        collectionView: UICollectionView,
        rowView: @escaping (Todo) -> AnyView,
        headerView: @escaping (TodoSection) -> AnyView
    ) {
        let cellReg = UICollectionView.CellRegistration<TodoCell, String> { _, _, _ in }
        super.init(collectionView: collectionView) { cv, indexPath, id in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: id)
        }
        rowViewProvider = rowView
        headerViewProvider = headerView

        let headerReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: Self.headerElementKind
        ) { [weak self] view, _, indexPath in
            guard let self,
                  let sid = self.snapshot().sectionIdentifiers[safe: indexPath.section],
                  let section = self.sectionsByID[sid],
                  let provider = self.headerViewProvider else { return }
            view.configure(with: provider(section))
        }
        supplementaryViewProvider = { cv, _, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    override func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(cv, cellForItemAt: indexPath)
        guard let id = itemIdentifier(for: indexPath) else { return cell }
        if let todoID = todoIDFromDetail(id) {
            if let todo = todosByID[todoID], let dv = detailView {
                cell.contentConfiguration = UIHostingConfiguration { dv(todo) }.margins(.all, 0)
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
