//
//  ScrollHost.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import SwiftUI
import UIKit

// MARK: - Public host

/// A SwiftUI ↔︎ UIKit bridge that renders one big, sectioned list (days) with sticky headers.
/// You feed it `TodoSection`s from your store; it renders SwiftUI rows/headers in a UICollectionView.
public struct TodoScrollHost: UIViewRepresentable {
    // DATA IN
    public var sections: [TodoSection]

    // RENDERERS (SwiftUI views for rows & headers)
    public var rowView: (Todo) -> AnyView
    public var headerView: (TodoSection) -> AnyView

    // CALLBACKS
    public var onCenteredSectionChange: (String) -> Void = { _ in }  // section.id
    public var onSelect: (String) -> Void = { _ in }                  // item.id

    // COLLAPSING HEADER PROGRESS (0..1)
    @Binding public var collapse: CGFloat

    public init(
        sections: [TodoSection],
        collapse: Binding<CGFloat>,
        onCenteredSectionChange: @escaping (String) -> Void = { _ in },
        onSelect: @escaping (String) -> Void = { _ in },
        rowView: @escaping (Todo) -> AnyView,
        headerView: @escaping (TodoSection) -> AnyView
    ) {
        self.sections = sections
        self._collapse = collapse
        self.onCenteredSectionChange = onCenteredSectionChange
        self.onSelect = onSelect
        self.rowView = rowView
        self.headerView = headerView
    }

    // MARK: UIViewRepresentable

    public func makeUIView(context: Context) -> UICollectionView {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: Layout.make())
        cv.backgroundColor = .clear
        cv.delegate = context.coordinator
        context.coordinator.install(on: cv, rowView: rowView, headerView: headerView)
        context.coordinator.apply(sections: sections, animated: false)
        return cv
    }

    public func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.onCenteredSectionChange = onCenteredSectionChange
        context.coordinator.onSelect = onSelect
        context.coordinator.collapse = $collapse
        context.coordinator.apply(sections: sections, animated: true)
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }
}

// MARK: - Coordinator

public extension TodoScrollHost {
    final class Coordinator: NSObject, UICollectionViewDelegate {
        private(set) weak var collectionView: UICollectionView?
        private var dataSource: DS!
        fileprivate var collapse: Binding<CGFloat> = .constant(0)
        fileprivate var onCenteredSectionChange: (String) -> Void = { _ in }
        fileprivate var onSelect: (String) -> Void = { _ in }

        func install(
            on cv: UICollectionView,
            rowView: @escaping (Todo) -> AnyView,
            headerView: @escaping (TodoSection) -> AnyView
        ) {
            self.collectionView = cv
            self.dataSource = DS(collectionView: cv, rowView: rowView, headerView: headerView)
        }

        func apply(sections: [TodoSection], animated: Bool) {
            var snap = NSDiffableDataSourceSnapshot<String, String>()
            // stash full sections for headers/cells and build ids
            dataSource.setPayload(sections)
            for s in sections {
                snap.appendSections([s.id])
                snap.appendItems(s.items.map(\.id), toSection: s.id)
            }
            dataSource.apply(snap, animatingDifferences: animated) { [weak self] in
                self?.updateCenteredSection()
            }
        }

        // MARK: Selection

        public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let id = dataSource.itemID(at: indexPath) else { return }
            onSelect(id)
        }

        // MARK: Scrolling feedback

        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Normalize to 0..1 over first ~120pt of scroll
            let p = max(0, min(1, scrollView.contentOffset.y / 120.0))
            collapse.wrappedValue = p
            updateCenteredSection()
        }

        private func updateCenteredSection() {
            guard let cv = collectionView else { return }
            // Consider the visual center of the viewport
            let centerY = cv.contentOffset.y + cv.bounds.size.height / 2.0
            // Find a visible index path closest to center
            let candidates = cv.indexPathsForVisibleItems
            guard !candidates.isEmpty else { return }
            let closest = candidates.min { a, b in
                let ra = cv.layoutAttributesForItem(at: a)?.frame.midY ?? 0
                let rb = cv.layoutAttributesForItem(at: b)?.frame.midY ?? 0
                return abs(ra - centerY) < abs(rb - centerY)
            }
            // Fall back to first visible section if needed
            let sectionIndex = (closest?.section) ?? candidates.map(\.section).min() ?? 0
            if let sid = dataSource.sectionID(at: sectionIndex) {
                onCenteredSectionChange(sid)
            }
        }
    }
}

// MARK: - Internal layout (sticky headers + self-sizing rows)

private enum Layout {
    static func make() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(60)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(60)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = .init(top: 8, leading: 0, bottom: 24, trailing: 0)

        // sticky header
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: DS.headerKind,
            alignment: .top
        )
        header.pinToVisibleBounds = true
        section.boundarySupplementaryItems = [header]

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 16

        return UICollectionViewCompositionalLayout(section: section, configuration: config)
    }
}

// MARK: - Internal diffable data source

private final class DS: UICollectionViewDiffableDataSource<String, String> {
    static let headerKind = "todo.section.header"

    // backing payload so headers/cells can resolve data quickly
    private var sectionsByID: [String: TodoSection] = [:]
    private var todosByID: [String: Todo] = [:]

    private var rowViewProvider: ((Todo) -> AnyView)?
    private var headerViewProvider: ((TodoSection) -> AnyView)?

    private var defaultRowProvider: ((UICollectionView, IndexPath, String) -> UICollectionViewCell)?

    private weak var owningCollectionView: UICollectionView?

    init(
        collectionView: UICollectionView,
        rowView: @escaping (Todo) -> AnyView,
        headerView: @escaping (TodoSection) -> AnyView
    ) {
        // Prepare registrations that do not capture `self` yet
        let cellReg = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, _ in
            // Basic setup; content will be provided by dataSource after init via provider lookup
            var bg = UIBackgroundConfiguration.clear()
            bg.backgroundColor = .clear
            cell.backgroundConfiguration = bg
            // We'll replace contentConfiguration in the dataSource cellProvider below where `self` is available
        }

        // Create a placeholder header registration that doesn't capture `self`
        // We'll actually install the real supplementary provider after super.init
        let headerReg = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(
            elementKind: Self.headerKind
        ) { _, _, _ in }

        // Call super.init with a cellProvider that can be updated to use our rowViewProvider after we set `self`
        super.init(collectionView: collectionView) { cv, indexPath, itemIdentifier in
            // Dequeue the configured cell
            let cell = cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: itemIdentifier)
            return cell
        }

        self.owningCollectionView = collectionView

        // Now it's safe to use `self`
        self.rowViewProvider = rowView
        self.headerViewProvider = headerView

        // Install a proper supplementary view provider that can reference `self`
        let realHeaderReg = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(
            elementKind: Self.headerKind
        ) { [weak self] view, _, indexPath in
            guard
                let self,
                let sectionID = self.snapshot().sectionIdentifiers[safe: indexPath.section],
                let section = self.sectionsByID[sectionID],
                let headerView = self.headerViewProvider
            else { return }

            let host = UIHostingController(rootView: headerView(section))
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false

            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        self.supplementaryViewProvider = { cv, _, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: realHeaderReg, for: indexPath)
        }

        // Update the cell provider to inject SwiftUI content using `self`
        self.setCellProvider(using: cellReg)
    }

    private func setCellProvider(using cellReg: UICollectionView.CellRegistration<UICollectionViewListCell, String>) {
        // Reassign the data source's cellProvider to inject SwiftUI content
        if let cv = self.owningCollectionView {
            cv.dataSource = self
        }
        self.defaultRowProvider = { [weak self] (cv: UICollectionView, indexPath: IndexPath, itemIdentifier: String) -> UICollectionViewCell in
            let cell = cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: itemIdentifier)
            if let self,
               let todo = self.todosByID[itemIdentifier],
               let rowView = self.rowViewProvider {
                cell.contentConfiguration = UIHostingConfiguration { rowView(todo) }
            }
            return cell
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let id = itemIdentifier(for: indexPath), let provider = defaultRowProvider {
            return provider(collectionView, indexPath, id)
        }
        // Fallback
        return super.collectionView(collectionView, cellForItemAt: indexPath)
    }

    // Payload wiring
    func setPayload(_ sections: [TodoSection]) {
        sectionsByID = sections.reduce(into: [:]) { $0[$1.id] = $1 }
        todosByID = sections.flatMap(\.items).reduce(into: [:]) { $0[$1.id] = $1 }
    }

    // Lookups
    func sectionID(at sectionIndex: Int) -> String? {
        snapshot().sectionIdentifiers[safe: sectionIndex]
    }

    func itemID(at indexPath: IndexPath) -> String? {
        let sectionIDs = snapshot().sectionIdentifiers
        guard indexPath.section < sectionIDs.count else { return nil }
        let sid = sectionIDs[indexPath.section]
        let itemIDs = snapshot().itemIdentifiers(inSection: sid)
        guard indexPath.item < itemIDs.count else { return nil }
        return itemIDs[indexPath.item]
    }
}

// MARK: - Safe subscripts

private extension Array {
    subscript(safe i: Int) -> Element? { (startIndex..<endIndex).contains(i) ? self[i] : nil }
}
