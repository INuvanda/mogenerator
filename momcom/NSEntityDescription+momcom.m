//
//  NSEntityDescription+momc.m
//  momc
//
//  Created by Tom Harrington on 4/17/13.
//  Copyright (c) 2013 Tom Harrington. All rights reserved.
//

#import "NSEntityDescription+momcom.h"
#import "NSAttributeDescription+momcom.h"
#import "NSRelationshipDescription+momcom.h"
#import "NSFetchedPropertyDescription+momcom.h"
#import "NSFetchRequest+momcom.h"

@implementation NSEntityDescription (momcom)

+ (NSEntityDescription *)baseEntityForXML:(NSXMLElement *)xmlNode
{
#pragma clang diagnostic push
#pragma ide diagnostic ignored "NotReleasedValue"
    NSEntityDescription *entityDescription = [[NSEntityDescription alloc] init];
#pragma clang diagnostic pop
    
    BOOL syncable = NO;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    NSMutableArray *properties = [NSMutableArray array];
    
    for (NSXMLNode *xmlAttribute in [xmlNode attributes]) {
        NSString *attributeName = [xmlAttribute name];
        NSString *attributeString = [xmlAttribute stringValue];
        if ([attributeName isEqualToString:@"name"]) {
            [entityDescription setName:attributeString];
        } else if ([attributeName isEqualToString:@"representedClassName"]) {
            [entityDescription setManagedObjectClassName:attributeString];
        } else if ([attributeName isEqualToString:@"elementID"]) {
            [entityDescription setRenamingIdentifier:attributeString];
        } else if ([attributeName isEqualToString:@"versionHashModifier"]) {
            [entityDescription setVersionHashModifier:attributeString];
        } else if ([attributeName isEqualToString:@"isAbstract"]) {
            if ([attributeString isEqualToString:@"YES"]) {
                [entityDescription setAbstract:YES];
            }
        } else if ([attributeName isEqualToString:@"syncable"]) {
            if ([attributeString isEqualToString:@"YES"]) {
                syncable = YES;
            }
        }
        // parentEntity attribute intentionally skipped here, it's handled later in postProcessEntityRelationshipsWithXML.
    }
    
    // Need to add com.apple.syncservices.Syncable = NO to self's userInfo unless syncable=YES appears in XML attributes.
    if (!syncable) {
        userInfo[@"com.apple.syncservices.Syncable"] = @"NO";
    }
    
    // Run through child elements, create properties and userInfo, but skip compoundIndexes for now.
    for (NSXMLElement *childNode in [xmlNode children]) {
        NSString *childNodeName = [childNode name];
        if ([childNodeName isEqualToString:@"attribute"]) {
            NSAttributeDescription *attributeDescription = [NSAttributeDescription baseEntityForXML:childNode];
            [properties addObject:attributeDescription];
        } else if ([childNodeName isEqualToString:@"relationship"]) {
            NSRelationshipDescription *relationshipDescription = [NSRelationshipDescription baseEntityForXML:childNode];
            [properties addObject:relationshipDescription];
        } else if ([childNodeName isEqualToString:@"fetchedProperty"]) {
            NSFetchedPropertyDescription *fetchedPropertyDescription = [NSFetchedPropertyDescription baseEntityForXML:childNode];
            [properties addObject:fetchedPropertyDescription];
        } else if ([childNodeName isEqualToString:@"userInfo"]) {
            for (NSXMLElement *entryElement in [childNode children]) {
                NSXMLNode *keyAttribute = [entryElement attributeForName:@"key"];
                NSXMLNode *valueAttribute = [entryElement attributeForName:@"value"];
                userInfo[[keyAttribute stringValue]] = [valueAttribute stringValue];
            }
        }
    }
    
    if ([userInfo count] > 0) {
        [entityDescription setUserInfo:userInfo];
    }
    if ([properties count] > 0) {
        [entityDescription setProperties:properties];
    }
    
    // Compound indexes require that attribute and relationship objects already exist.
    NSError *compoundIndexXpathError = nil;
    NSArray *compoundIndexElements = [xmlNode nodesForXPath:@"compoundIndexes/compoundIndex" error:&compoundIndexXpathError];
    if ([compoundIndexElements count] > 0) {
        NSMutableArray *compoundIndexes = [NSMutableArray array];
        for (NSXMLElement *compoundIndexElement in compoundIndexElements) {
            NSMutableArray *currentCompoundIndex = [NSMutableArray array];
            NSArray *compoundIndexNameElements = [compoundIndexElement nodesForXPath:@"index" error:nil];
            for (NSXMLElement *compoundIndexNameElement in compoundIndexNameElements) {
                NSString *compoundIndexName = [[compoundIndexNameElement attributeForName:@"value"] stringValue];
                NSPropertyDescription *compoundIndexProperty = [entityDescription propertiesByName][compoundIndexName];
                [currentCompoundIndex addObject:compoundIndexProperty];
            }
            if ([currentCompoundIndex count] > 0) {
                [compoundIndexes addObject:currentCompoundIndex];
            }
        }
        if ([compoundIndexes count] > 0) {
            [entityDescription setCompoundIndexes:compoundIndexes];
        }
    }
    
    return entityDescription;
}

/*
 Things that have to wait until after all entities exist-- or that require creating placeholder entities:
 - Entity inheritance
 - Relationships (need to know destination entity)
 - Inverse relationships (need to get a relationship object from the related entity to set the inverse, because it's the same object, not merely a similar one that belongs to the source entity).
 - Fetched properties (need to have the target entity for the fetch request).
 */
- (void)postProcessEntityRelationshipsWithXML:(NSXMLElement *)xmlElement
{
    NSXMLNode *parentEntityNode = [xmlElement attributeForName:@"parentEntity"];
    if (parentEntityNode != nil) {
        NSString *parentEntityName = [parentEntityNode stringValue];
        NSEntityDescription *parentEntity = [[self managedObjectModel] entitiesByName][parentEntityName];
        [self _setParentEntity:parentEntity];
    }
    
    NSError *relationshipXpathError = nil;
    NSArray *relationshipNodes = [xmlElement nodesForXPath:@"relationship" error:&relationshipXpathError];
    for (NSXMLElement *relationshipNode in relationshipNodes) {
        NSString *relationshipName = [[relationshipNode attributeForName:@"name"] stringValue];
        NSRelationshipDescription *relationship = [self propertiesByName][relationshipName];
        
        NSString *destinationEntityName = [[relationshipNode attributeForName:@"destinationEntity"] stringValue];
        NSEntityDescription *destinationEntity = [[self managedObjectModel] entitiesByName][destinationEntityName];
        [relationship setDestinationEntity:destinationEntity];

        NSXMLNode *inverseNameElement = [relationshipNode attributeForName:@"inverseName"];
        NSXMLNode *inverseEntityElement = [relationshipNode attributeForName:@"inverseEntity"];
        
        if ((inverseNameElement != nil) && (inverseEntityElement != nil)) {
            // It's not clear whether it's possible for the inverse entity to not be the same as the destination entity.
            // They're stored separately, so they're handled separately.
            NSString *inverseEntityName = [inverseEntityElement stringValue];
            NSEntityDescription *inverseEntity = [[self managedObjectModel] entitiesByName][inverseEntityName];
            
            NSString *inverseName = [inverseNameElement stringValue];
            NSRelationshipDescription *inverseRelationship = [inverseEntity propertiesByName][inverseName];
            [relationship setInverseRelationship:inverseRelationship];
        }
    }
    
    NSError *fetchedPropertyXpathError = nil;
    NSArray *fetchedPropertyNodes = [xmlElement nodesForXPath:@"fetchedProperty" error:&fetchedPropertyXpathError];
    for (NSXMLElement *fetchedPropertyNode in fetchedPropertyNodes) {
        NSString *fetchedPropertyName = [[fetchedPropertyNode attributeForName:@"name"] stringValue];
        NSFetchedPropertyDescription *fetchedPropertyDescription = [self propertiesByName][fetchedPropertyName];

        NSFetchRequest *fetchRequest = nil;
        
        NSArray *fetchRequestElements = [fetchedPropertyNode children];
        if ([fetchRequestElements count] == 1) {
            NSXMLElement *fetchRequestElement = fetchRequestElements[0];
            fetchRequest = [NSFetchRequest fetchRequestForXML:fetchRequestElement inManagedObjectModel:[self managedObjectModel]];
        }

        [fetchedPropertyDescription setFetchRequest:fetchRequest];
    }
}

- (void)_setParentEntity:(NSEntityDescription *)parentEntity
{
#pragma clang diagnostic push
#pragma ide diagnostic ignored "NotReleasedValue"
    NSMutableArray *parentSubentities = [[parentEntity subentities] mutableCopy];
#pragma clang diagnostic pop
    if (parentSubentities == nil) {
        parentSubentities = [NSMutableArray array];
    }
    [parentSubentities addObject:self];
    [parentEntity setSubentities:parentSubentities];
}
@end
