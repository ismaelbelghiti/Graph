//
// Copyright (C) 2015 GraphKit, Inc. <http://graphkit.io> and other GraphKit contributors.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program located at the root of the software package
// in a file called LICENSE.  If not, see <http://www.gnu.org/licenses/>.
//

import CoreData

internal struct GraphPersistentStoreCoordinator {
	internal static var onceToken: dispatch_once_t = 0
	internal static var persistentStoreCoordinator: NSPersistentStoreCoordinator?
}

internal struct GraphManagedObjectContext {
	internal static var onceToken: dispatch_once_t = 0
	internal static var managedObjectContext: NSManagedObjectContext?
}

internal struct GraphManagedObjectModel {
	internal static var onceToken: dispatch_once_t = 0
	internal static var managedObjectModel: NSManagedObjectModel?
}

internal struct GraphUtility {
	internal static let storeName: String = "GraphKit.sqlite"

	internal static let entityIndexName: String = "ManagedEntity"
	internal static let entityDescriptionName: String = entityIndexName
	internal static let entityObjectClassName: String = entityIndexName
	internal static let entityGroupIndexName: String = "ManagedEntityGroup"
	internal static let entityGroupObjectClassName: String = entityGroupIndexName
	internal static let entityGroupDescriptionName: String = entityGroupIndexName
	internal static let entityPropertyIndexName: String = "ManagedEntityProperty"
	internal static let entityPropertyObjectClassName: String = entityPropertyIndexName
	internal static let entityPropertyDescriptionName: String = entityPropertyIndexName

	internal static let actionIndexName: String = "ManagedAction"
	internal static let actionDescriptionName: String = actionIndexName
	internal static let actionObjectClassName: String = actionIndexName
	internal static let actionGroupIndexName: String = "ManagedActionGroup"
	internal static let actionGroupObjectClassName: String = actionGroupIndexName
	internal static let actionGroupDescriptionName: String = actionGroupIndexName
	internal static let actionPropertyIndexName: String = "ManagedActionProperty"
	internal static let actionPropertyObjectClassName: String = actionPropertyIndexName
	internal static let actionPropertyDescriptionName: String = actionPropertyIndexName

	internal static let bondIndexName: String = "ManagedBond"
	internal static let bondDescriptionName: String = bondIndexName
	internal static let bondObjectClassName: String = bondIndexName
	internal static let bondGroupIndexName: String = "ManagedBondGroup"
	internal static let bondGroupObjectClassName: String = bondGroupIndexName
	internal static let bondGroupDescriptionName: String = bondGroupIndexName
	internal static let bondPropertyIndexName: String = "ManagedBondProperty"
	internal static let bondPropertyObjectClassName: String = bondPropertyIndexName
	internal static let bondPropertyDescriptionName: String = bondPropertyIndexName
}

@objc(GraphDelegate)
public protocol GraphDelegate {
	optional func graphDidInsertEntity(graph: Graph, entity: Entity)
	optional func graphDidDeleteEntity(graph: Graph, entity: Entity)
	optional func graphDidInsertEntityGroup(graph: Graph, entity: Entity, group: String)
	optional func graphDidDeleteEntityGroup(graph: Graph, entity: Entity, group: String)
	optional func graphDidInsertEntityProperty(graph: Graph, entity: Entity, property: String, value: AnyObject)
	optional func graphDidUpdateEntityProperty(graph: Graph, entity: Entity, property: String, value: AnyObject)
	optional func graphDidDeleteEntityProperty(graph: Graph, entity: Entity, property: String, value: AnyObject)

	optional func graphDidInsertAction(graph: Graph, action: Action)
	optional func graphDidUpdateAction(graph: Graph, action: Action)
	optional func graphDidDeleteAction(graph: Graph, action: Action)
	optional func graphDidInsertActionGroup(graph: Graph, action: Action, group: String)
	optional func graphDidDeleteActionGroup(graph: Graph, action: Action, group: String)
	optional func graphDidInsertActionProperty(graph: Graph, action: Action, property: String, value: AnyObject)
	optional func graphDidUpdateActionProperty(graph: Graph, action: Action, property: String, value: AnyObject)
	optional func graphDidDeleteActionProperty(graph: Graph, action: Action, property: String, value: AnyObject)

	optional func graphDidInsertBond(graph: Graph, bond: Bond)
	optional func graphDidDeleteBond(graph: Graph, bond: Bond)
	optional func graphDidInsertBondGroup(graph: Graph, bond: Bond, group: String)
	optional func graphDidDeleteBondGroup(graph: Graph, bond: Bond, group: String)
	optional func graphDidInsertBondProperty(graph: Graph, bond: Bond, property: String, value: AnyObject)
	optional func graphDidUpdateBondProperty(graph: Graph, bond: Bond, property: String, value: AnyObject)
	optional func graphDidDeleteBondProperty(graph: Graph, bond: Bond, property: String, value: AnyObject)
}

@objc(Graph)
public class Graph : NSObject {
	/**
		:name:	batchSize
	*/
	public var batchSize: Int = 0 // 0 == no limit
	
	/**
		:name:	batchOffset
	*/
	public var batchOffset: Int = 0
	
	//
	//	:name:	watchers
	//
	internal lazy var watchers: SortedDictionary<String, SortedSet<String>> = SortedDictionary<String, SortedSet<String>>()
	
	//
	//	:name:	materPredicate
	//
	internal var masterPredicate: NSPredicate?
	
	/**
		:name:	init
	*/
	public override init() {
		super.init()
	}
	
	//
	//	:name:	deinit
	//
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	/**
		:name:	delegate
	*/
	public weak var delegate: GraphDelegate?

	/**
		:name:	save
	*/
	public func save() {
		save(nil)
	}

	/**
		:name:	save
	*/
	public func save(completion: ((success: Bool, error: NSError?) -> Void)?) {
		if let moc: NSManagedObjectContext = worker {
			if moc.hasChanges {
				do {
					try moc.save()
					completion?(success: true, error: nil)
				} catch let e as NSError {
					completion?(success: false, error: e)
				}
			}
		}
	}

	/**
		:name:	worker
	*/
	internal var worker: NSManagedObjectContext? {
		dispatch_once(&GraphManagedObjectContext.onceToken) {
			GraphManagedObjectContext.managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
			GraphManagedObjectContext.managedObjectContext?.persistentStoreCoordinator = self.persistentStoreCoordinator
		}
		return GraphManagedObjectContext.managedObjectContext
	}

	//
	//	:name:	managedObjectModel
	//
	internal var managedObjectModel: NSManagedObjectModel? {
		dispatch_once(&GraphManagedObjectModel.onceToken) {
			GraphManagedObjectModel.managedObjectModel = NSManagedObjectModel()
			
			let entityDescription: NSEntityDescription = NSEntityDescription()
			var entityProperties: Array<AnyObject> = Array<AnyObject>()
			entityDescription.name = GraphUtility.entityDescriptionName
			entityDescription.managedObjectClassName = GraphUtility.entityObjectClassName
			
			let actionDescription: NSEntityDescription = NSEntityDescription()
			var actionProperties: Array<AnyObject> = Array<AnyObject>()
			actionDescription.name = GraphUtility.actionDescriptionName
			actionDescription.managedObjectClassName = GraphUtility.actionObjectClassName
			
			let bondDescription: NSEntityDescription = NSEntityDescription()
			var bondProperties: Array<AnyObject> = Array<AnyObject>()
			bondDescription.name = GraphUtility.bondDescriptionName
			bondDescription.managedObjectClassName = GraphUtility.bondObjectClassName
			
			let entityPropertyDescription: NSEntityDescription = NSEntityDescription()
			var entityPropertyProperties: Array<AnyObject> = Array<AnyObject>()
			entityPropertyDescription.name = GraphUtility.entityPropertyDescriptionName
			entityPropertyDescription.managedObjectClassName = GraphUtility.entityPropertyObjectClassName
			
			let actionPropertyDescription: NSEntityDescription = NSEntityDescription()
			var actionPropertyProperties: Array<AnyObject> = Array<AnyObject>()
			actionPropertyDescription.name = GraphUtility.actionPropertyDescriptionName
			actionPropertyDescription.managedObjectClassName = GraphUtility.actionPropertyObjectClassName
			
			let bondPropertyDescription: NSEntityDescription = NSEntityDescription()
			var bondPropertyProperties: Array<AnyObject> = Array<AnyObject>()
			bondPropertyDescription.name = GraphUtility.bondPropertyDescriptionName
			bondPropertyDescription.managedObjectClassName = GraphUtility.bondPropertyObjectClassName
			
			let entityGroupDescription: NSEntityDescription = NSEntityDescription()
			var entityGroupProperties: Array<AnyObject> = Array<AnyObject>()
			entityGroupDescription.name = GraphUtility.entityGroupDescriptionName
			entityGroupDescription.managedObjectClassName = GraphUtility.entityGroupObjectClassName
			
			let actionGroupDescription: NSEntityDescription = NSEntityDescription()
			var actionGroupProperties: Array<AnyObject> = Array<AnyObject>()
			actionGroupDescription.name = GraphUtility.actionGroupDescriptionName
			actionGroupDescription.managedObjectClassName = GraphUtility.actionGroupObjectClassName
			
			let bondGroupDescription: NSEntityDescription = NSEntityDescription()
			var bondGroupProperties: Array<AnyObject> = Array<AnyObject>()
			bondGroupDescription.name = GraphUtility.bondGroupDescriptionName
			bondGroupDescription.managedObjectClassName = GraphUtility.bondGroupObjectClassName
			
			let nodeClass: NSAttributeDescription = NSAttributeDescription()
			nodeClass.name = "nodeClass"
			nodeClass.attributeType = .Integer64AttributeType
			nodeClass.optional = false
			entityProperties.append(nodeClass.copy() as! NSAttributeDescription)
			actionProperties.append(nodeClass.copy() as! NSAttributeDescription)
			bondProperties.append(nodeClass.copy() as! NSAttributeDescription)
			
			let type: NSAttributeDescription = NSAttributeDescription()
			type.name = "type"
			type.attributeType = .StringAttributeType
			type.optional = false
			entityProperties.append(type.copy() as! NSAttributeDescription)
			actionProperties.append(type.copy() as! NSAttributeDescription)
			bondProperties.append(type.copy() as! NSAttributeDescription)
			
			let createdDate: NSAttributeDescription = NSAttributeDescription()
			createdDate.name = "createdDate"
			createdDate.attributeType = .DateAttributeType
			createdDate.optional = false
			entityProperties.append(createdDate.copy() as! NSAttributeDescription)
			actionProperties.append(createdDate.copy() as! NSAttributeDescription)
			bondProperties.append(createdDate.copy() as! NSAttributeDescription)
			
			let propertyName: NSAttributeDescription = NSAttributeDescription()
			propertyName.name = "name"
			propertyName.attributeType = .StringAttributeType
			propertyName.optional = false
			entityPropertyProperties.append(propertyName.copy() as! NSAttributeDescription)
			actionPropertyProperties.append(propertyName.copy() as! NSAttributeDescription)
			bondPropertyProperties.append(propertyName.copy() as! NSAttributeDescription)
			
			let propertyValue: NSAttributeDescription = NSAttributeDescription()
			propertyValue.name = "object"
			propertyValue.attributeType = .TransformableAttributeType
			propertyValue.attributeValueClassName = "AnyObject"
			propertyValue.optional = false
			propertyValue.storedInExternalRecord = true
			entityPropertyProperties.append(propertyValue.copy() as! NSAttributeDescription)
			actionPropertyProperties.append(propertyValue.copy() as! NSAttributeDescription)
			bondPropertyProperties.append(propertyValue.copy() as! NSAttributeDescription)
			
			let propertyRelationship: NSRelationshipDescription = NSRelationshipDescription()
			propertyRelationship.name = "node"
			propertyRelationship.minCount = 1
			propertyRelationship.maxCount = 1
			propertyRelationship.optional = false
			propertyRelationship.deleteRule = .NoActionDeleteRule
			
			let propertySetRelationship: NSRelationshipDescription = NSRelationshipDescription()
			propertySetRelationship.name = "propertySet"
			propertySetRelationship.minCount = 0
			propertySetRelationship.maxCount = 0
			propertySetRelationship.optional = false
			propertySetRelationship.deleteRule = .CascadeDeleteRule
			propertyRelationship.inverseRelationship = propertySetRelationship
			propertySetRelationship.inverseRelationship = propertyRelationship
			
			propertyRelationship.destinationEntity = entityDescription
			propertySetRelationship.destinationEntity = entityPropertyDescription
			entityPropertyProperties.append(propertyRelationship.copy() as! NSRelationshipDescription)
			entityProperties.append(propertySetRelationship.copy() as! NSRelationshipDescription)
			
			propertyRelationship.destinationEntity = actionDescription
			propertySetRelationship.destinationEntity = actionPropertyDescription
			actionPropertyProperties.append(propertyRelationship.copy() as! NSRelationshipDescription)
			actionProperties.append(propertySetRelationship.copy() as! NSRelationshipDescription)
			
			propertyRelationship.destinationEntity = bondDescription
			propertySetRelationship.destinationEntity = bondPropertyDescription
			bondPropertyProperties.append(propertyRelationship.copy() as! NSRelationshipDescription)
			bondProperties.append(propertySetRelationship.copy() as! NSRelationshipDescription)
			
			let group: NSAttributeDescription = NSAttributeDescription()
			group.name = "name"
			group.attributeType = .StringAttributeType
			group.optional = false
			entityGroupProperties.append(group.copy() as! NSAttributeDescription)
			actionGroupProperties.append(group.copy() as! NSAttributeDescription)
			bondGroupProperties.append(group.copy() as! NSAttributeDescription)
			
			let groupRelationship: NSRelationshipDescription = NSRelationshipDescription()
			groupRelationship.name = "node"
			groupRelationship.minCount = 1
			groupRelationship.maxCount = 1
			groupRelationship.optional = false
			groupRelationship.deleteRule = .NoActionDeleteRule
			
			let groupSetRelationship: NSRelationshipDescription = NSRelationshipDescription()
			groupSetRelationship.name = "groupSet"
			groupSetRelationship.minCount = 0
			groupSetRelationship.maxCount = 0
			groupSetRelationship.optional = false
			groupSetRelationship.deleteRule = .CascadeDeleteRule
			groupRelationship.inverseRelationship = groupSetRelationship
			groupSetRelationship.inverseRelationship = groupRelationship
			
			groupRelationship.destinationEntity = entityDescription
			groupSetRelationship.destinationEntity = entityGroupDescription
			entityGroupProperties.append(groupRelationship.copy() as! NSRelationshipDescription)
			entityProperties.append(groupSetRelationship.copy() as! NSRelationshipDescription)
			
			groupRelationship.destinationEntity = actionDescription
			groupSetRelationship.destinationEntity = actionGroupDescription
			actionGroupProperties.append(groupRelationship.copy() as! NSRelationshipDescription)
			actionProperties.append(groupSetRelationship.copy() as! NSRelationshipDescription)
			
			groupRelationship.destinationEntity = bondDescription
			groupSetRelationship.destinationEntity = bondGroupDescription
			bondGroupProperties.append(groupRelationship.copy() as! NSRelationshipDescription)
			bondProperties.append(groupSetRelationship.copy() as! NSRelationshipDescription)
			
			// Inverse relationship for Subjects -- B.
			let actionSubjectSetRelationship: NSRelationshipDescription = NSRelationshipDescription()
			actionSubjectSetRelationship.name = "subjectSet"
			actionSubjectSetRelationship.minCount = 0
			actionSubjectSetRelationship.maxCount = 0
			actionSubjectSetRelationship.optional = false
			actionSubjectSetRelationship.deleteRule = .NullifyDeleteRule
			actionSubjectSetRelationship.destinationEntity = entityDescription
			
			let actionSubjectRelationship: NSRelationshipDescription = NSRelationshipDescription()
			actionSubjectRelationship.name = "actionSubjectSet"
			actionSubjectRelationship.minCount = 0
			actionSubjectRelationship.maxCount = 0
			actionSubjectRelationship.optional = false
			actionSubjectRelationship.deleteRule = .CascadeDeleteRule
			actionSubjectRelationship.destinationEntity = actionDescription
			actionSubjectRelationship.inverseRelationship = actionSubjectSetRelationship
			actionSubjectSetRelationship.inverseRelationship = actionSubjectRelationship
			
			entityProperties.append(actionSubjectRelationship.copy() as! NSRelationshipDescription)
			actionProperties.append(actionSubjectSetRelationship.copy() as! NSRelationshipDescription)
			// Inverse relationship for Subjects -- E.
			
			// Inverse relationship for Objects -- B.
			let actionObjectSetRelationship: NSRelationshipDescription = NSRelationshipDescription()
			actionObjectSetRelationship.name = "objectSet"
			actionObjectSetRelationship.minCount = 0
			actionObjectSetRelationship.maxCount = 0
			actionObjectSetRelationship.optional = false
			actionObjectSetRelationship.deleteRule = .NullifyDeleteRule
			actionObjectSetRelationship.destinationEntity = entityDescription
			
			let actionObjectRelationship: NSRelationshipDescription = NSRelationshipDescription()
			actionObjectRelationship.name = "actionObjectSet"
			actionObjectRelationship.minCount = 0
			actionObjectRelationship.maxCount = 0
			actionObjectRelationship.optional = false
			actionObjectRelationship.deleteRule = .CascadeDeleteRule
			actionObjectRelationship.destinationEntity = actionDescription
			actionObjectRelationship.inverseRelationship = actionObjectSetRelationship
			actionObjectSetRelationship.inverseRelationship = actionObjectRelationship
			
			entityProperties.append(actionObjectRelationship.copy() as! NSRelationshipDescription)
			actionProperties.append(actionObjectSetRelationship.copy() as! NSRelationshipDescription)
			// Inverse relationship for Objects -- E.
			
			// Inverse relationship for Subjects -- B.
			let bondSubjectSetRelationship = NSRelationshipDescription()
			bondSubjectSetRelationship.name = "subject"
			bondSubjectSetRelationship.minCount = 1
			bondSubjectSetRelationship.maxCount = 1
			bondSubjectSetRelationship.optional = true
			bondSubjectSetRelationship.deleteRule = .NullifyDeleteRule
			bondSubjectSetRelationship.destinationEntity = entityDescription
			
			let bondSubjectRelationship: NSRelationshipDescription = NSRelationshipDescription()
			bondSubjectRelationship.name = "bondSubjectSet"
			bondSubjectRelationship.minCount = 0
			bondSubjectRelationship.maxCount = 0
			bondSubjectRelationship.optional = false
			bondSubjectRelationship.deleteRule = .CascadeDeleteRule
			bondSubjectRelationship.destinationEntity = bondDescription
			
			bondSubjectRelationship.inverseRelationship = bondSubjectSetRelationship
			bondSubjectSetRelationship.inverseRelationship = bondSubjectRelationship
			
			entityProperties.append(bondSubjectRelationship.copy() as! NSRelationshipDescription)
			bondProperties.append(bondSubjectSetRelationship.copy() as! NSRelationshipDescription)
			// Inverse relationship for Subjects -- E.
			
			// Inverse relationship for Objects -- B.
			let bondObjectSetRelationship = NSRelationshipDescription()
			bondObjectSetRelationship.name = "object"
			bondObjectSetRelationship.minCount = 1
			bondObjectSetRelationship.maxCount = 1
			bondObjectSetRelationship.optional = true
			bondObjectSetRelationship.deleteRule = .NullifyDeleteRule
			bondObjectSetRelationship.destinationEntity = entityDescription
			
			let bondObjectRelationship: NSRelationshipDescription = NSRelationshipDescription()
			bondObjectRelationship.name = "bondObjectSet"
			bondObjectRelationship.minCount = 0
			bondObjectRelationship.maxCount = 0
			bondObjectRelationship.optional = false
			bondObjectRelationship.deleteRule = .CascadeDeleteRule
			bondObjectRelationship.destinationEntity = bondDescription
			bondObjectRelationship.inverseRelationship = bondObjectSetRelationship
			bondObjectSetRelationship.inverseRelationship = bondObjectRelationship
			
			entityProperties.append(bondObjectRelationship.copy() as! NSRelationshipDescription)
			bondProperties.append(bondObjectSetRelationship.copy() as! NSRelationshipDescription)
			// Inverse relationship for Objects -- E.
			
			entityDescription.properties = entityProperties as! [NSPropertyDescription]
			entityGroupDescription.properties = entityGroupProperties as! [NSPropertyDescription]
			entityPropertyDescription.properties = entityPropertyProperties as! [NSPropertyDescription]
			
			actionDescription.properties = actionProperties as! [NSPropertyDescription]
			actionGroupDescription.properties = actionGroupProperties as! [NSPropertyDescription]
			actionPropertyDescription.properties = actionPropertyProperties as! [NSPropertyDescription]
			
			bondDescription.properties = bondProperties as! [NSPropertyDescription]
			bondGroupDescription.properties = bondGroupProperties as! [NSPropertyDescription]
			bondPropertyDescription.properties = bondPropertyProperties as! [NSPropertyDescription]
			
			GraphManagedObjectModel.managedObjectModel?.entities = [
				entityDescription,
				entityGroupDescription,
				entityPropertyDescription,
				
				actionDescription,
				actionGroupDescription,
				actionPropertyDescription,
				
				bondDescription,
				bondGroupDescription,
				bondPropertyDescription
			]
		}
		return GraphManagedObjectModel.managedObjectModel
	}

	//
	//	:name:	persistentStoreCoordinator
	//
	internal var persistentStoreCoordinator: NSPersistentStoreCoordinator? {
		dispatch_once(&GraphPersistentStoreCoordinator.onceToken) {
			do {
				let documentsDirectory: String = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
				try NSFileManager.defaultManager().createDirectoryAtPath(documentsDirectory, withIntermediateDirectories: true, attributes: nil)
				let url: NSURL = NSURL.fileURLWithPath(documentsDirectory + "/" + GraphUtility.storeName, isDirectory: false)
				let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel!)
				do {
					try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
				} catch {
					var dict: Dictionary<String, AnyObject> = Dictionary<String, AnyObject>()
					dict[NSLocalizedDescriptionKey] = "[GraphKit Error: Failed to initialize datastore.]"
					dict[NSLocalizedFailureReasonErrorKey] = "[GraphKit Error: There was an error creating or loading the application's saved data.]"
					dict[NSUnderlyingErrorKey] = error as NSError
					print(NSError(domain: "GraphKit", code: 9999, userInfo: dict))
				}
				GraphPersistentStoreCoordinator.persistentStoreCoordinator = coordinator
			} catch {}
		}
		return GraphPersistentStoreCoordinator.persistentStoreCoordinator
	}
}
