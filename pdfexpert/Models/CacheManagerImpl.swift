//
//  CacheManagerImpl.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 22/03/23.
//

import Foundation
import Factory

extension Container {
    var cacheManager: Factory<CacheManager> {
        self { CacheManagerImpl() }.singleton
    }
}

class CacheManagerImpl: CacheManager {
    
    enum CacheManagerKey: String {
        case onboardingShown
    }
    
    enum FileName: String {
        case signature
    }
    
    private let mainUserDefaults = UserDefaults.standard
    
    var onboardingShown: Bool {
        get { self.getBool(forKey: CacheManagerKey.onboardingShown.rawValue) ?? false }
        set { self.saveBool(newValue, forKey: CacheManagerKey.onboardingShown.rawValue) }
    }
    
    var signatureData: Data? {
        get { Self.getFileData(forFileName: .signature) }
        set { Self.saveFileData(newValue, forFileName: .signature) }
    }
        
    // MARK: - Private methods
    
    private func save<T>(encodable: T?, forKey key: String) where T: Encodable {
        if let encodable = encodable {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(encodable) {
                self.mainUserDefaults.set(encoded, forKey: key)
            }
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func load<T>(forKey key: String) -> T? where T: Decodable {
        if let encodedData = self.mainUserDefaults.object(forKey: key) as? Data {
            let decoder = JSONDecoder()
            if let object = try? decoder.decode(T.self, from: encodedData) {
                return object
            }
        }
        return nil
    }
    
    private func saveNSSecureCoding<T>(object: T?, forKey key: String) where T: NSSecureCoding {
        if let object = object {
            if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) {
                self.mainUserDefaults.set(encoded, forKey: key)
            }
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func loadNSSecureCoding<T>(forKey key: String) -> T? where T: NSSecureCoding & NSObject {
        if let encodedData = self.mainUserDefaults.object(forKey: key) as? Data {
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: encodedData)
        }
        return nil
    }
    
    private func saveData(_ value: Data?, forKey key: String) {
        if let value = value {
            self.mainUserDefaults.set(value, forKey: key)
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func getData(forKey key: String) -> Data? {
        return self.mainUserDefaults.data(forKey: key)
    }
    
    private func saveString(_ value: String?, forKey key: String) {
        if let value = value {
            self.mainUserDefaults.set(value, forKey: key)
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func getString(forKey key: String) -> String? {
        return self.mainUserDefaults.string(forKey: key)
    }
    
    private func saveInteger(_ value: Int?, forKey key: String) {
        if let value = value {
            self.mainUserDefaults.set(value, forKey: key)
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func getInteger(forKey key: String) -> Int? {
        if self.mainUserDefaults.object(forKey: key) != nil {
            return self.mainUserDefaults.integer(forKey: key)
        } else {
            return nil
        }
    }
    
    private func saveBool(_ value: Bool?, forKey key: String) {
        if let value = value {
            self.mainUserDefaults.set(value, forKey: key)
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func getBool(forKey key: String) -> Bool? {
        if self.mainUserDefaults.object(forKey: key) != nil {
            return self.mainUserDefaults.bool(forKey: key)
        } else {
            return nil
        }
    }
    
    private func reset(forKey key: String) {
        self.mainUserDefaults.removeObject(forKey: key)
    }
    
    private static func saveFileData(_ fileData: Data?, forFileName fileName: FileName) {
        let url = Self.getFilePathInDocument(fileName: fileName)
        if let fileData = fileData {
            try? fileData.write(to: url)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private static func getFileData(forFileName fileName: FileName) -> Data? {
        return FileManager.default.contents(atPath: Self.getFilePathInDocument(fileName: fileName).path)
    }
    
    private static func getFilePathInDocument(fileName: FileName) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(component: fileName.rawValue)
    }
}
