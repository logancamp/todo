# Todo

A native iOS todo app built with SwiftUI and UIKit, backed by Firebase. Todos are organized into collapsible sections, can be pinned to the top, reordered by drag and drop, and edited inline without leaving the list.

> **Status:** In active development, working toward a personal MVP.

## Features

- **Sections** – group todos into collapsible sections with a rotating chevron header
- **Pinning** – pin important todos so they always sort first, marked with an orange pin icon
- **Drag-and-drop reordering** – order persists using fractional indexing, so moving one item doesn't rewrite the whole list
- **Inline editing** – tap a row to expand it in place and edit the title, date, and details
- **Swipe actions** – swipe to pin/unpin or delete
- **Accounts and sync** – sign in with Firebase Auth; data lives in Firestore

## Tech Stack

| Layer | Technology |
| --- | --- |
| UI | SwiftUI, with UIKit (`UICollectionView`) for the list |
| Data source | `UICollectionViewDiffableDataSource` |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Abuse protection | Firebase App Check |

## Architecture

The list screen is a hybrid: SwiftUI views for rows, headers, and screens, hosted inside a `UICollectionView` for precise control over scrolling, reordering, and swipe actions.

- **`TodoScrollHost`** – a `UIViewRepresentable` wrapping the `UICollectionView`. It owns the diffable data source, drag-and-drop, selection, and swipe actions.
- **`HostingCell`** – a custom `UICollectionViewCell` that embeds each SwiftUI row through a `UIHostingController` and self-sizes via `systemLayoutSizeFitting`. This is used instead of `UIHostingConfiguration`, whose gesture recognizers conflict with UIKit swipe actions.
- **`TodoStore`** – holds the data logic: loading, sectioning (`recomputeSections()`), pinning, ordering, and Firestore reads and writes.
- **`Todo`** – the model, with a custom decoder that supplies defaults (for example `isPinned = false`) so older documents keep decoding.
- **Expand/edit state** – row expansion is driven by `expandedTodoID`. All edit state is set synchronously before the ID changes so the row never renders with a blank field. Tap handling goes through `didSelectItemAt` rather than SwiftUI tap gestures.
- **Date pickers** – presented in sheets, which avoids section jumping while a row is expanded.

## Getting Started

### Prerequisites

- macOS with a recent version of Xcode
- An iOS simulator or device
- A Firebase project with **Authentication**, **Cloud Firestore**, and **App Check** enabled

### Setup

1. Clone the repo:

   ```bash
   git clone https://github.com/logancamp/todo.git
   cd todo
   ```

2. Open the project:

   ```bash
   open Todo.xcodeproj
   ```

3. **Connect your own Firebase project.** Replace `GoogleService-Info.plist` in the project root with the file for your own Firebase iOS app (Firebase Console → Project settings → Your apps), and make sure the bundle identifier in Xcode matches it.

4. **Enable sign-in.** In the Firebase Console, go to Authentication → Sign-in method and enable the provider(s) the app uses.

5. **Set Firestore security rules** so each user can only read and write their own data.

6. **Register an App Check debug token for the simulator.** Run the app once, copy the debug token printed in the Xcode console, and add it in Firebase Console → App Check → your app → Manage debug tokens.

7. Select a simulator or device and press **Run** (`⌘R`).

## Project Structure

```
todo/
├── Todo.xcodeproj/          # Xcode project
├── Todo/                    # App source
└── GoogleService-Info.plist # Firebase configuration
```

## Roadmap

- [x] Sections with collapse/expand
- [x] Pinning with pinned-first sorting
- [x] Inline expand-to-edit rows
- [ ] Swipe actions on hosted cells (in progress)
- [ ] Remaining UI polish and features for personal MVP

## Notes

- Deleting a user's Firestore data does not delete their Firebase Auth account. To remove a user entirely, delete them in Firebase Console → Authentication → Users.
- Security relies on Firebase Auth, App Check, and Firestore security rules. There is no client-side encryption.

## License

No license has been specified yet.
