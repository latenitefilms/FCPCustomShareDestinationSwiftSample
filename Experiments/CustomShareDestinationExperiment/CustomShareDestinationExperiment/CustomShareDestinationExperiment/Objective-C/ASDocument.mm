/****************************************************************************************
 * Copyright 2001-2015 Automatic Duck,Inc.  All Rights reserved 
 *
 *
 * XMotionDocument.mm  $Revision: 1 $
 *
 *		Description
 *
 *
 ***************************************************************************************/

#import <AppKit/NSApplication.h>

#import "ASDocument.h"
#import "ASAsset.h"
#import "ASWindowController.h"

#import "FCPXMetadataKeys.h"
#import "scriptLog.h"
#import "MediaAssetHelperKeys.h"


@implementation ASDocument
{
	// properties of the colllection
	NSMutableArray *collection;             // array of SAMAsset
	NSMutableDictionary *URLHash;           // asset URL to index
	NSMutableDictionary *UniqueIDHash;      // asset UniqueID to index
	
	// scripting bookkeeping
	id container; /* reference to the object containing this object */
	NSString* containerProperty; /* name of the cocoa key on container specifying the
								  list property where this object is stored */
	
	/* storage for our id and name AppleScript properties. */
	NSString* uniqueID; /* a unique id value for this object */
	
	NSDictionary* defaultAssetLocation;     // default location for new asset
	
	// the window controller for the document window
	ASWindowController *primaryWindowController;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		// create the collection array
		collection = [NSMutableArray arrayWithCapacity:0];
		URLHash = [NSMutableDictionary dictionaryWithCapacity:0];
		UniqueIDHash = [NSMutableDictionary dictionaryWithCapacity:0];
		collectionName = [self displayName];
		
		uniqueID = [ASObject calculateNewUniqueID];
	}
	return self;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	self = [super initWithContentsOfURL:url ofType:typeName error:outError];
	if (self) {
		// create the collection array
		collection = [NSMutableArray arrayWithCapacity:0];
		URLHash = [NSMutableDictionary dictionaryWithCapacity:0];
		UniqueIDHash = [NSMutableDictionary dictionaryWithCapacity:0];
		collectionName = [[url URLByDeletingPathExtension] lastPathComponent];
		
		uniqueID = [ASObject calculateNewUniqueID];
	}
	return self;
}

- (void)makeWindowControllers
{
	primaryWindowController = [[ASWindowController alloc] init];
	
	[self addWindowController:primaryWindowController];
}

@synthesize collectionName;
@synthesize collectionDescription;
@synthesize collection;

@synthesize defaultAssetLocation;

@synthesize primaryWindowController;


#pragma mark <<< Scripting Support Methods >>>

/* standard setter and getter methods for the container and
 containerProperty slots.  The only thing that's unusual here is that
 we have lumped the setter functions together because we will always
 call them together. */
- (id)container {
	SLOG(@" of %@ as %@", self.uniqueID, container);
	return container;
}

- (NSString *)containerProperty {
	SLOG(@" return  %@ as '%@'", self.uniqueID, containerProperty);
	return containerProperty;
}

- (void)setContainer:(id)value andProperty:(NSString *)property {
	SLOG(@" of %@ to %@ and '%@'", self.uniqueID, [value class], property);
	if (container != value) {
		container = value;
	}
	if (containerProperty != property) {
		containerProperty = [property copy];
	}
}

/* standard setter and getter methods for the 'uniqueID' property
 nothing out of the ordinary here. */
- (NSString *)uniqueID {
	return uniqueID;
}

- (void)setUniqueID:(NSString *)value {
	SLOG(@" of %@ to '%@'", self.uniqueID, value);
	if (uniqueID != value) {
		uniqueID = [value copy];
	}
}


/* standard setter and getter methods for the 'name' property
 nothing out of the ordinary here. */
- (NSString *)name {
	SLOG(@" of %@ as '%@'", self.uniqueID, self.collectionName);
	return self.collectionName;
}

- (void)setName:(NSString *)value {
	SLOG(@" of %@ to '%@'", self.uniqueID, value);
	if (self.collectionName != value) {
		self.collectionName = [value copy];
	}
}


#pragma mark <<< Asset Access Methods >>>

- (NSURL*)assetURLAtIndex:(NSUInteger)index
{
	ASAsset *asset = (ASAsset*)[self.collection objectAtIndex:index];
	
	if ( asset == nil )
		return nil;
	else
		return [asset principalURL];
}

- (NSUInteger)assetIndexForURL:(NSURL*)url
{
	NSNumber *indexObject = [URLHash objectForKey:url];
	
	if ( indexObject != NULL )
		return [indexObject integerValue];
	else
		return -1;
}

- (NSUInteger)assetIndexForUniqueID:(NSString*)theID
{
	NSNumber *indexObject = [UniqueIDHash objectForKey:theID];
	
	if ( indexObject != NULL )
		return [indexObject integerValue];
	else
		return -1;
}

- (NSUInteger)assetIndexForLocation:(NSDictionary*)locationInfo;
{
	NSURL       *folderURL = [locationInfo objectForKey:kMediaAssetLocationFolderKey];
	NSString    *baseName = [locationInfo objectForKey:kMediaAssetLocationBasenameKey];
	
	if ( folderURL == nil || baseName == nil )
		return -1;
	
	NSURL       *principalURL = [folderURL URLByAppendingPathComponent:baseName];
	
	return [self assetIndexForURL:principalURL];
}

- (NSUInteger)addAssetAtLocation:(NSDictionary*)locationInfo
						 content:(BOOL)load
						metadata:(NSDictionary*)metadataset
					 dataOptions:(NSDictionary*)options;
{
	ASAsset    *theAsset = nil;
	NSUInteger  assetIndex = [self assetIndexForLocation:locationInfo];
	NSNumber    *hasMediaObject = [locationInfo objectForKey:kMediaAssetLocationHasMediaKey];
	NSNumber    *hasDescObject = [locationInfo objectForKey:kMediaAssetLocationHasDescriptionKey];
#if 0
	BOOL        hasMedia = hasMediaObject != nil && [hasMediaObject boolValue];
#else
	BOOL        hasMedia = NO ;
#endif
	BOOL        hasDesc = hasDescObject != nil && [hasDescObject boolValue];
	NSString*   mediaExtension = nil;
	NSString*   descExtension = nil;
	
	if ( mediaExtension == nil && hasMedia )
		mediaExtension = @"mov";
	if ( descExtension == nil && hasDesc )
		descExtension = @"fcpxml";
	
	if ( assetIndex == -1 ) {
		assetIndex = [self.assets count];
		theAsset = [[ASAsset alloc] init:[locationInfo objectForKey:kMediaAssetLocationBasenameKey]
									   at:[locationInfo objectForKey:kMediaAssetLocationFolderKey]
									media:mediaExtension
									 desc:descExtension];
		
		[theAsset setMetadata:metadataset];
		[theAsset addMetadata:@"1" forKey:kASMetadataKeyManagedAsset];
		[theAsset setDataOptions:options];
		[self insertInAssets:theAsset atIndex:(unsigned int)assetIndex];
	}
	else {
		theAsset = [self.assets objectAtIndex:assetIndex];
		
		if ( mediaExtension != nil )
			[theAsset setMediaExtension:mediaExtension];
		else if ( hasMediaObject != nil && ! hasMedia )
			[theAsset setMediaExtension:nil];               // remove the extension if that was an explicit NO
		if ( descExtension != nil )
			[theAsset setDescExtension:descExtension];
		else if ( hasDescObject != nil && ! hasDesc )
			[theAsset setDescExtension:nil];                // remove the extension if that was an explicit NO
		
		for ( NSString* key in metadataset ) {
			[theAsset addMetadata:[metadataset objectForKey:key] forKey:key];
		}
		for ( NSString* key in options ) {
			[theAsset setDataOption:[options objectForKey:key] forKey:key];
		}
	}
	
	if ( load ) {
		if ( hasMedia  )
			[theAsset loadMedia];
		if ( hasDesc )
			[theAsset loadDescription];
	}
	
	// update the UI
	[primaryWindowController updateOutlineView:nil];
	[primaryWindowController updateSelectionDetailFields];
	
	return assetIndex;
}


- (NSUInteger)addAssetAtURL:(NSURL*)url content:(BOOL)load metadata:(NSDictionary*)metadataset dataOptions:(NSDictionary*)options
{
	NSURL           *principalURL = [url URLByDeletingPathExtension];
	NSURL           *folderURL = [principalURL URLByDeletingLastPathComponent];
	NSString        *baseName = [principalURL lastPathComponent];
	NSString        *extension = [url pathExtension];
	NSDictionary    *locationInfo = nil;
	
	if ( [ASAsset isMediaExtension:extension] ) {
		locationInfo = [NSDictionary dictionaryWithObjectsAndKeys:folderURL, kMediaAssetLocationFolderKey,
						baseName, kMediaAssetLocationBasenameKey,
						[NSNumber numberWithBool:YES], kMediaAssetLocationHasMediaKey,
						nil];
	}
	else if ( [ASAsset isDescExtension:extension] ) {
		locationInfo = [NSDictionary dictionaryWithObjectsAndKeys:folderURL, kMediaAssetLocationFolderKey,
						baseName, kMediaAssetLocationBasenameKey,
						[NSNumber numberWithBool:YES], kMediaAssetLocationHasDescriptionKey,
						nil];
	}
	else {
		// register with basename only
		locationInfo = [NSDictionary dictionaryWithObjectsAndKeys:folderURL, kMediaAssetLocationFolderKey, baseName, kMediaAssetLocationBasenameKey, nil];
	}
	
	return [self addAssetAtLocation:locationInfo content:load metadata:metadataset dataOptions:options];
}


- (void)removeAssetAtIndex:(NSUInteger)index
{
	[self removeFromAssetsAtIndex:(unsigned int)index];
}

- (void)removeAsset:(ASAsset*)asset
{
	[URLHash removeObjectForKey:[asset principalURL]];
	[UniqueIDHash removeObjectForKey:asset.uniqueID];
	[self.collection removeObject:asset];
}


- (NSUInteger)addURL:(NSURL*)url
			 content:(BOOL)load
			metadata:(NSDictionary*)metadataset
		 dataOptions:(NSDictionary*)dataOptions
{
	NSURL*      principalURL = nil;
	NSUInteger  assetIndex = -1;
	
	if ( principalURL == nil ) {
		// if the URL does not represent a role file then add the URL as a standalone non-role asset
		assetIndex = [self addAssetAtURL:url content:load metadata:metadataset dataOptions:dataOptions];
	}
	
	// update UI
	[primaryWindowController updateOutlineView:nil];
	[primaryWindowController updateSelectionDetailFields];
	
	return assetIndex;
}


#pragma mark <<< KVC Asset Accessors >>>


/* kvc methods for the 'assets' AppleScript element.  Here we implement the methods
 necessary for maintaining the list of assets inside of a Bucket.  Note the names.
 I our scripting definition file we specified that the 'bucket' class contains an
 element of type 'asset', like so:
 <element type="asset"/>
 Cocoa will use the plural form of the class name, 'assets',  when naming the
 property used by AppleScript to access the list of buckets, and we should use
 the property name when naming our methods.  So, using the property name, we
 name our methods as follows:
 - (NSArray*) assets;
 -(void) insertInAssets:(id) asset;
 -(void) insertInAssets:(id) asset atIndex:(unsigned)index;
 -(void) removeFromAssetsAtIndex:(unsigned)index;
 */


/* return the entire list of assets */
- (NSArray*) assets {
	SLOG(@"returning assets from a bucket %@", self.uniqueID);
	return self.collection;
}

/* insert a asset at the beginning of the list */
-(void) insertInAssets:(id) asset {
	ASAsset* assetObject = (ASAsset*)asset;
	NSNumber *indexObject = [NSNumber numberWithInteger:0];
	SLOG(@"inserting asset %@ into bucket %@", assetObject.uniqueID, self.uniqueID);
	[asset setContainer:self andProperty:@"assets"];
	[self.collection insertObject:assetObject atIndex:0];
	[URLHash setObject:indexObject forKey:[assetObject principalURL]];
	[UniqueIDHash setObject:indexObject forKey:assetObject.uniqueID];
}

/* insert a asset at some position in the list */
-(void) insertInAssets:(id) asset atIndex:(unsigned)index {
	ASAsset* assetObject = (ASAsset*)asset;
	NSNumber *indexObject = [NSNumber numberWithInteger:index];
	SLOG(@"insert asset %@ at index %d into bucket %@", assetObject.uniqueID, index, self.uniqueID);
	[asset setContainer:self andProperty:@"assets"];
	[self.collection insertObject:assetObject atIndex:index];
	[URLHash setObject:indexObject forKey:[assetObject principalURL]];
	[UniqueIDHash setObject:indexObject forKey:assetObject.uniqueID];
}

/* remove a asset from the list */
-(void) removeFromAssetsAtIndex:(unsigned)index {
	SLOG(@"removing asset at %d from bucket %@", index, self.uniqueID);
	ASAsset* assetObject = [self.collection objectAtIndex:index];
	[URLHash removeObjectForKey:[assetObject principalURL]];
	[UniqueIDHash removeObjectForKey:assetObject.uniqueID];
	[self.collection removeObjectAtIndex:index];
}

/* resolve an object specifier into an asset index */
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier
{
	if ([specifier isKindOfClass:[NSUniqueIDSpecifier class]]) {
		NSUniqueIDSpecifier     *theSpecifier = (NSUniqueIDSpecifier*)specifier;
		NSString    *theID = [theSpecifier uniqueID];
		NSInteger   index = [self assetIndexForUniqueID:theID];
		
		if ( index == -1 ) {
			return [NSArray array];
		}
		else {
			return [NSArray arrayWithObject:[NSNumber numberWithInteger:index]];
		}
	}
	else
		return nil;
}


#pragma mark <<< Serialization / Deserialization >>>

+ (BOOL)autosavesInPlace
{
	return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSData *dataToWrite = nil;
	
	if ( [typeName isEqualToString:@"Asset Collection"]) {
		NSMutableArray *urlStrings = [NSMutableArray arrayWithCapacity:0];
		
		for ( ASAsset *asset in self.collection ) {
			NSString *string = [[asset mediaFile] absoluteString];
			
			[urlStrings addObject:string];
		}
		
		dataToWrite = [[urlStrings componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
	}
	else {
		if ( outError != NULL )
			*outError = [NSError errorWithDomain:@"SimpleAssetManaer" code:304 userInfo:nil];
	}
	
	return dataToWrite;
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if ( [typeName isEqualToString:@"Asset Collection"]) {
		
		NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSArray *urlStrings = [dataString componentsSeparatedByString:@"\n"];
		
		// empty the content of the document
		[self.collection removeAllObjects];
		
		// populate the new content
		for ( NSString *urlString in urlStrings ) {
			NSURL *url = [NSURL URLWithString:urlString];
			ASAsset *newAsset = [[ASAsset alloc] init:url];
			
			[self insertInAssets:newAsset atIndex:(unsigned int)[self.assets count]];
		}
		return YES;
	}
	else {
		if ( outError != NULL )
			*outError = [NSError errorWithDomain:@"SimpleAssetManaer" code:204 userInfo:nil];
		
		return NO;
	}
}


#pragma mark ======== load and save data methods =========
/*
 ** --------------------------------------------------------
 **    Standard NSDocument load and save data methods
 ** --------------------------------------------------------
 
 These methods create an archive of the collection and unarchive an existing archive to reconstitute the collection.
 
 For more details, see:
 - NSDocument Class Reference
 - Document-Based Applications Overview
 */

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	// create an archive of the collection and its attributes
	NSKeyedArchiver *archiver;
	NSMutableData *data = [NSMutableData data];
	
	archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	
	[archiver encodeObject:self.collectionName forKey:@"name"];
	[archiver encodeObject:self.collectionDescription forKey:@"collectionDescription"];
	[archiver encodeObject:self.collection forKey:@"collection"];
	
	[archiver finishEncoding];
	
	return data;
}


- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
	NSKeyedUnarchiver *unarchiver;
	
	// extract an archive of the collection and its attributes
	unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
	
	self.collectionName = [unarchiver decodeObjectForKey:@"name"];
	self.collectionDescription = [unarchiver decodeObjectForKey:@"collectionDescription"];
	self.collection = [unarchiver decodeObjectForKey:@"collection"];
	
	[unarchiver finishDecoding];
	
	return YES;
}

@end

/**************************************************************************************
 * $Log: ASDocument.mm $
 * Revision 1 2015/11/25 07:02:00 -0800 harry /FinalCutProX/ADII/harryp
 * init version.
 * 
 *
 *************************************************************************************/
