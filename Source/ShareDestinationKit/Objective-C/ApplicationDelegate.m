//
//  ApplicationDelegate.h
//  ShareDestinationKit
//
//  Created by Chris Hocking on 10/12/2023.
//

#import "ApplicationDelegate.h"
#import "ScriptingSupportCategories.h"

#import <Cocoa/Cocoa.h>

@implementation ApplicationDelegate

// ------------------------------------------------------------
// Application should quit after last window closed:
// ------------------------------------------------------------
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

// ------------------------------------------------------------
// Open a list of files.
// Also stick a list of object specifiers for opened object,
// if there is incoming OpenDoc AppleEvent.
// ------------------------------------------------------------
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    NSLog(@"[ShareDestinationKit] INFO - openFiles triggered!");
    
    NSAppleEventManager *aemanager = [NSAppleEventManager sharedAppleEventManager];
    NSAppleEventDescriptor *currentEvent = [aemanager currentAppleEvent];
    NSAppleEventDescriptor *currentReply = [aemanager currentReplyAppleEvent];
    NSAppleEventDescriptor *directParams = [currentEvent descriptorForKeyword:keyDirectObject];
    NSAppleEventDescriptor *resultDesc = [currentReply descriptorForKeyword:keyDirectObject];
    
    if ( currentEvent != nil && directParams != nil ) {
        NSArray *urls = [NSArray scriptingUserListWithDescriptor:directParams];

        NSLog(@"[ShareDestinationKit] INFO - Open Document URLs: %@", urls);
    }

    if ( resultDesc == nil ) {
        resultDesc = [NSAppleEventDescriptor listDescriptor];
    }
    
    NSDocumentController *docController = [NSDocumentController sharedDocumentController];

    [self openFileInFileNameList:filenames
                         atIndex:0
                  withController:docController
                     docDescList:directParams
                  resultDescList:resultDesc];

    [currentReply setDescriptor:resultDesc forKeyword:keyDirectObject];
    
    if ( currentReply != nil && resultDesc != nil ) {
        NSLog(@"Opened Objects:%@.", resultDesc);
    }
}

- (void)openFileInFileNameList:(NSArray*)filenames
                       atIndex:(NSUInteger)index
                withController:(NSDocumentController*)docController
                   docDescList:(NSAppleEventDescriptor*)directParams
                resultDescList:(NSAppleEventDescriptor*)resultDesc
{
    
    NSLog(@"[ShareDestinationKit] INFO - openFileInFileNameList triggered!");
    
    if ( index >= [filenames count] )
        return;
    
    NSURL *url = [[NSURL fileURLWithPath:[filenames objectAtIndex:index]] URLByResolvingSymlinksInPath];

    [docController openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
        
        id opendObject = document;
        NSScriptObjectSpecifier *opendObjectSpec = [opendObject objectSpecifier];
        
        if ( opendObjectSpec != nil ) {
            [resultDesc insertDescriptor:[opendObjectSpec descriptor] atIndex:index + 1];
        }
        
        [self openFileInFileNameList:filenames
                             atIndex:index + 1
                      withController:docController
                         docDescList:directParams
                      resultDescList:resultDesc];
    }];
}

@end
