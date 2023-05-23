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
            _ = K.Test.GetDebugPdf(context: viewContext, password: (index % 2 > 0) ? "Test" : nil)
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
            
            let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: CloudKitContainerIdentifier)
            
            cloudKitContainerOptions.databaseScope = .private
            privateStoreDescription.cloudKitContainerOptions = cloudKitContainerOptions
            
            /**
             Load the persistent stores.
             */
            self.container.loadPersistentStores(completionHandler: { (loadedStoreDescription, error) in
                guard error == nil else {
                    fatalError("#\(#function): Failed to load persistent stores:\(error!)")
                }
                guard let cloudKitContainerOptions = loadedStoreDescription.cloudKitContainerOptions else {
                    return
                }
                if cloudKitContainerOptions.databaseScope == .private {
                    self._privatePersistentStore = self.container.persistentStoreCoordinator.persistentStore(for: loadedStoreDescription.url!)
                }
            })
            
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
//        processHistoryAsynchronously(storeUUID: storeUUID)
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
