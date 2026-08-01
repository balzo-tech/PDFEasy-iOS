//
//  Persistence.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import CoreData
import Factory
import CloudKit

private var CloudKitContainerIdentifier: String = "iCloud.eu.balzo.pdfexpert"
private var InitializeCloudKitSchema: Bool = false

extension Container {
    var persistence: Factory<PersistenceController> {
        self {
            #if DEBUG
            if K.Test.UseMockDB || isPreview() {
                return PersistenceController.preview
            } else {
                return PersistenceController()
            }
            #else
            PersistenceController()
            #endif
        }.singleton
    }
}

struct TransactionAuthor {
    static let app = "app"
}

class PersistenceController {

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for index in 0..<K.Test.NumberOfPdfs {
            _ = K.Test.GetDebugCoreDataPdf(context: viewContext)
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        if inMemory {
            self.container = NSPersistentContainer(name: "AppCoreData")
            self.container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            self.container.loadPersistentStores(completionHandler: { (storeDescription, error) in
                if let error = error as NSError? {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            })
            self.container.viewContext.automaticallyMergesChangesFromParent = true
        } else {
            /**
             Prepare the containing folder for the Core Data stores.
             A Core Data store has companion files, so it's a good practice to put a store under a folder.
             */
            let baseURL = NSPersistentContainer.defaultDirectoryURL()
            let storeFolderURL = baseURL.appendingPathComponent("CoreDataStores")
            let privateStoreFolderURL = storeFolderURL.appendingPathComponent("Private")
            
            let fileManager = FileManager.default
            for folderURL in [privateStoreFolderURL] where !fileManager.fileExists(atPath: folderURL.path) {
                do {
                    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    fatalError("#\(#function): Failed to create the store folder: \(error)")
                }
            }
            
            let cloudKitContainer = NSPersistentCloudKitContainer(name: "AppCoreData")
            self.container = cloudKitContainer
            
            /**
             Grab the default (first) store and associate it with the CloudKit private database.
             Set up the store description by:
             - Specifying a filename for the store.
             - Enabling history tracking and remote notifications.
             - Specifying the iCloud container and database scope.
             */
            guard let privateStoreDescription = self.container.persistentStoreDescriptions.first else {
                fatalError("#\(#function): Failed to retrieve a persistent store description.")
            }
            privateStoreDescription.url = privateStoreFolderURL.appendingPathComponent("private.sqlite")
            
            privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            privateStoreDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            privateStoreDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            if Self.isCloudKitDisabledForDevelopment {
                // A build signed ad-hoc, without a provisioning profile, carries no
                // iCloud entitlement, and CloudKit answers that by trapping deep
                // inside the mirroring delegate's own queue — nothing the store
                // loader below can catch. Asking for the mirroring at all is what
                // has to be skipped. Only ever true in a debug build told to.
                print("#\(#function): CloudKit mirroring disabled by PDFPRO_DISABLE_CLOUDKIT.")
                self.isCloudKitEnabled = false
            } else {
                let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: CloudKitContainerIdentifier)

                cloudKitContainerOptions.databaseScope = .private
                privateStoreDescription.cloudKitContainerOptions = cloudKitContainerOptions
            }
            
            /**
             Load the persistent stores.

             A failure here used to be fatal, which is only defensible while
             CloudKit is guaranteed to be there. It is not on the Mac: the
             mirroring delegate refuses to start when the iCloud container is
             unreachable — no account signed in, an entitlement the local build
             was not granted — and the whole archive would be unreachable
             because the sync half of it is. The documents live in the local
             store either way, so a second attempt without mirroring keeps the
             app usable and simply stops syncing.
             */
            var loadFailure: Error?
            self.container.loadPersistentStores(completionHandler: { (loadedStoreDescription, error) in
                guard error == nil else {
                    loadFailure = error
                    return
                }
                self.assignPrivateStore(from: loadedStoreDescription)
            })

            if let loadFailure {
                print("#\(#function): CloudKit-backed store unavailable, falling back to a local-only store: \(loadFailure)")
                self.isCloudKitEnabled = false
                privateStoreDescription.cloudKitContainerOptions = nil
                self.container.loadPersistentStores(completionHandler: { (loadedStoreDescription, error) in
                    guard error == nil else {
                        fatalError("#\(#function): Failed to load persistent stores:\(error!)")
                    }
                    self.assignPrivateStore(from: loadedStoreDescription)
                })
            }
            
            /**
             Run initializeCloudKitSchema() once to update the CloudKit schema every time you change the Core Data model.
             Don't call this code in the production environment.
             */
            if InitializeCloudKitSchema {
                do {
                    try cloudKitContainer.initializeCloudKitSchema()
                } catch {
                    print("\(#function): initializeCloudKitSchema: \(error)")
                }
            } else {
                self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                self.container.viewContext.transactionAuthor = TransactionAuthor.app
                
                /**
                 Automatically merge the changes from other contexts.
                 */
                self.container.viewContext.automaticallyMergesChangesFromParent = true
                
                /**
                 Pin the viewContext to the current generation token and set it to keep itself up-to-date with local changes.
                 */
                do {
                    try self.container.viewContext.setQueryGenerationFrom(.current)
                } catch {
                    fatalError("#\(#function): Failed to pin viewContext to the current generation:\(error)")
                }
                
                /**
                 Observe the following notifications:
                 - The remote change notifications from container.persistentStoreCoordinator.
                 - The .NSManagedObjectContextDidSave notifications from any context.
                 - The event change notifications from the container.
                 */
                NotificationCenter.default.addObserver(self, selector: #selector(self.storeRemoteChange(_:)),
                                                       name: .NSPersistentStoreRemoteChange,
                                                       object: self.container.persistentStoreCoordinator)
                NotificationCenter.default.addObserver(self, selector: #selector(self.containerEventChanged(_:)),
                                                       name: NSPersistentCloudKitContainer.eventChangedNotification,
                                                       object: self.container)
            }
        }
    }
    
    private var _privatePersistentStore: NSPersistentStore?
    var privatePersistentStore: NSPersistentStore {
        return _privatePersistentStore!
    }

    /// False when the store had to be loaded without CloudKit mirroring. What
    /// the user writes stays on this device until the app is launched again
    /// somewhere the container answers.
    private(set) var isCloudKitEnabled: Bool = true

    static var isCloudKitDisabledForDevelopment: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["PDFPRO_DISABLE_CLOUDKIT"] == "1"
        #else
        false
        #endif
    }

    private func assignPrivateStore(from description: NSPersistentStoreDescription) {
        guard let url = description.url else { return }
        self._privatePersistentStore = self.container.persistentStoreCoordinator.persistentStore(for: url)
    }
    
    lazy var cloudKitContainer: CKContainer = {
        return CKContainer(identifier: CloudKitContainerIdentifier)
    }()
        
    /**
     An operation queue for handling history-processing tasks: watching changes, deduplicating tags, and triggering UI updates, if needed.
     */
    lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

extension PersistenceController {
    /**
     Handle .NSPersistentStoreRemoteChange notifications.
     Process persistent history to merge relevant changes to the context, and deduplicate the tags, if necessary.
     */
    @objc
    func storeRemoteChange(_ notification: Notification) {
        guard let storeUUID = notification.userInfo?[NSStoreUUIDKey] as? String,
              [privatePersistentStore.identifier].contains(storeUUID) else {
            print("\(#function): Ignore a store remote Change notification because of no valid storeUUID.")
            return
        }
        self.deduplicateAsynchronously()
    }

    /**
     Handle the container's event change notifications (NSPersistentCloudKitContainer.eventChangedNotification).
     */
    @objc
    func containerEventChanged(_ notification: Notification) {
         guard let value = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey],
              let event = value as? NSPersistentCloudKitContainer.Event else {
            print("\(#function): Failed to retrieve the container event from notification.userInfo.")
            return
        }
        if event.error != nil {
            print("\(#function): Received a persistent CloudKit container event changed notification.\n\(event)")
        }
    }
}

// MARK: - Deduplication

extension PersistenceController {

    /// The entities whose identity is the name the user typed, and which therefore
    /// arrive twice. A document cannot: it is created once, on one device.
    static let deduplicatedEntityNames = ["Folder", "Tag"]

    /// Runs a merge pass off the main thread, one at a time (`historyQueue` is
    /// serial), so a burst of imports cannot have two passes fighting each other.
    func deduplicateAsynchronously() {
        self.historyQueue.addOperation { [weak self] in
            guard let self = self else { return }
            let context = self.container.newBackgroundContext()
            context.transactionAuthor = TransactionAuthor.app
            context.performAndWait {
                self.deduplicateNamedEntities(in: context)
            }
        }
    }

    /// Merges the folders and the tags that share a name, keeping one of each.
    ///
    /// Nothing in the model identifies a folder but its name: two devices that each
    /// create "Work" while offline create two separate records, CloudKit brings both
    /// down, and the archive shows the folder twice with the documents split between
    /// them. Every duplicate's documents are re-filed onto the survivor before the
    /// duplicate goes, so nothing is lost — a folder is only a label on documents
    /// that live elsewhere.
    ///
    /// The survivor is chosen from the synced data alone — oldest first, then color,
    /// then name — never from anything local like an object ID. Each device runs this
    /// on its own copy and has to reach the same verdict, or two devices would each
    /// delete what the other kept.
    func deduplicateNamedEntities(in context: NSManagedObjectContext) {
        for entityName in Self.deduplicatedEntityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            guard let entities = try? context.fetch(request), entities.count > 1 else { continue }

            // Names are compared the way a person would read them: "Work" and "work "
            // are the same folder typed twice, not two folders.
            let groups = Dictionary(grouping: entities) { entity in
                (entity.value(forKey: "name") as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() ?? ""
            }

            for (name, duplicates) in groups where !name.isEmpty && duplicates.count > 1 {
                let ordered = duplicates.sorted(by: Self.comesFirst)
                guard let survivor = ordered.first else { continue }
                Self.merge(Array(ordered.dropFirst()), into: survivor, context: context)
            }
        }

        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("\(#function): Failed to save the deduplicated context: \(error)")
        }
    }

    /// A total order over duplicates that every device computes the same way,
    /// because it only reads values CloudKit carries. `distantFuture` for a missing
    /// date puts the incomplete record last, where it will be the one merged away.
    private static func comesFirst(_ first: NSManagedObject, _ second: NSManagedObject) -> Bool {
        let firstDate = first.value(forKey: "creationDate") as? Date ?? .distantFuture
        let secondDate = second.value(forKey: "creationDate") as? Date ?? .distantFuture
        if firstDate != secondDate { return firstDate < secondDate }

        let firstColor = first.value(forKey: "colorIndex") as? Int32 ?? 0
        let secondColor = second.value(forKey: "colorIndex") as? Int32 ?? 0
        if firstColor != secondColor { return firstColor < secondColor }

        // Same name up to case and spacing, so this only settles "Work" vs "work".
        return (first.value(forKey: "name") as? String ?? "")
            < (second.value(forKey: "name") as? String ?? "")
    }

    /// Re-files every document of the losing records onto `survivor`, then deletes
    /// them. Works through `mutableSetValue(forKey:)` so Core Data maintains the
    /// inverse relationship itself: a folder's documents are moved by the same call
    /// that adds them here, and a tag's are shared rather than moved.
    private static func merge(_ losers: [NSManagedObject],
                              into survivor: NSManagedObject,
                              context: NSManagedObjectContext) {
        let survivingPdfs = survivor.mutableSetValue(forKey: "pdfs")
        for loser in losers {
            // Copied first: for a folder, adding a document to the survivor removes
            // it from the loser's own set, and that would be mutation under iteration.
            for pdf in loser.mutableSetValue(forKey: "pdfs").allObjects {
                survivingPdfs.add(pdf)
            }
            context.delete(loser)
        }
    }
}
