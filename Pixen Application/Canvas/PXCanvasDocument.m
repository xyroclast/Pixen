//
//  PXCanvasDocument.m
//  Pixen
//
//  Copyright 2005-2012 Pixen Project. All rights reserved.
//

#import "PXCanvasDocument.h"

#import "PXCanvasWindowController.h"
#import "PXCanvas.h"
#import "PXCanvas_ImportingExporting.h"
#import "PXCanvas_CopyPaste.h"
#import "PXCanvas_Drawing.h"
#import "PXCanvas_Modifying.h"
#import "PXCanvas_Layers.h"
#import "PXPalette.h"
#import "PXCanvasView.h"
#import "PXLayerController.h"
#import "PXIconExporter.h"
#import "PXAnimatedGifExporter.h"
#import "PXLayer.h"
#import "PXCanvasWindowController_IBActions.h"
#import "UTType+NSString.h"

BOOL isPowerOfTwo(int num);

@implementation PXCanvasDocument

@synthesize canvas = _canvas;

- (id)init
{
	if ( ! ( self = [super init] ) ) 
		return nil;
	
	self.canvas = [[PXCanvas new] autorelease];
	
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
	
	return self;
}

- (void)setCanvas:(PXCanvas *)aCanvas
{
	if (_canvas != aCanvas) {
		[_canvas release];
		_canvas = [aCanvas retain];
		
		[_canvas setUndoManager:[self undoManager]];
	}
}

- (void)dealloc
{
	[self.windowController releaseCanvas];
	
	[_canvas release];
	
	[super dealloc];
}

- (PXCanvasController *)canvasController
{
	return [self.windowController canvasController];
}

- (void)initWindowController
{
	self.windowController = [[[PXCanvasWindowController alloc] initWithWindowNibName:@"PXCanvasDocument"] autorelease];
}

- (void)setWindowControllerData
{
	[self.windowController setCanvas:_canvas];
}

BOOL isPowerOfTwo(int num)
{
	double logResult = log2(num);
	return (logResult == (int)logResult);
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	NSString *lastType = [[NSUserDefaults standardUserDefaults] stringForKey:PXLastSavedFileType];
	
	if (!lastType)
		lastType = PixenImageFileType;
	
	NSView *accessoryView = [savePanel accessoryView];
	NSPopUpButton *popUpButton = nil;
	
	if ([[accessoryView subviews] count]) {
		NSView *box = [[accessoryView subviews] objectAtIndex:0];
		
		if ([[box subviews] count]) {
			for (NSView *view in [box subviews]) {
				if ([view isKindOfClass:[NSPopUpButton class]]) {
					popUpButton = (NSPopUpButton *) view;
					break;
				}
			}
		}
	}
	
	if (popUpButton) {
		NSString *name = (NSString *) UTTypeCopyDescription((__bridge CFStringRef)lastType);
		[popUpButton selectItemWithTitle:name];
		[name release];
	}
	
	return YES;
}

+ (NSData *)dataRepresentationOfType:(NSString *)aType withCanvas:(PXCanvas *)canvas
{
	if (UTTypeEqualNSString(aType, PixenImageFileType) ||
		UTTypeEqualNSString(aType, PixenImageFileTypeOld)) {
		
		return [NSKeyedArchiver archivedDataWithRootObject:canvas];
	}
	else if (UTTypeEqual(kUTTypeJPEG, (__bridge CFStringRef) aType))
	{
		return [canvas imageDataWithType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0]
																							   forKey:NSImageCompressionFactor]];
	}
	else if (UTTypeEqual(kUTTypeICO, (__bridge CFStringRef) aType))
	{
		PXIconExporter *iconExporter = [[[PXIconExporter alloc] init] autorelease];
		return [iconExporter iconDataForCanvas:canvas];
	}
	else if (UTTypeEqual(kUTTypePNG, (__bridge CFStringRef) aType))
	{
		return [canvas imageDataWithType:NSPNGFileType properties:nil];
	}
	else if (UTTypeEqual(kUTTypeTIFF, (__bridge CFStringRef) aType))
	{
		return [canvas imageDataWithType:NSTIFFFileType properties:nil];
	}
	else if (UTTypeEqual(kUTTypeGIF, (__bridge CFStringRef) aType))
	{
		return [canvas imageDataWithType:NSGIFFileType properties:nil];
	}
	else if (UTTypeEqual(kUTTypeBMP, (__bridge CFStringRef) aType))
	{
		return [canvas imageDataWithType:NSBMPFileType properties:nil];
	}
	else if (UTTypeEqual(kUTTypePICT, (__bridge CFStringRef) aType))
	{
		NSMutableData *pictData = [NSMutableData data];
		
		CGImageDestinationRef pictOutput = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)pictData,
																			kUTTypePICT,
																			1,
																			NULL);
		
		CGImageDestinationAddImage(pictOutput,
								   [[canvas displayImage] CGImageForProposedRect:NULL
																		 context:nil
																		   hints:nil],
								   NULL);
		
		CGImageDestinationFinalize(pictOutput);
		CFRelease(pictOutput);
		
		return pictData;
	}
	
	return nil;
}

- (NSData *)dataOfType:(NSString *)type error:(NSError **)err
{
	[[NSUserDefaults standardUserDefaults] setObject:type forKey:PXLastSavedFileType];
	
	if (UTTypeEqual(kUTTypeJPEG, (__bridge CFStringRef) type))
	{
		NSDictionary *props = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0f]
														  forKey:NSImageCompressionFactor];
		
		return [_canvas imageDataWithType:NSJPEGFileType properties:props];
	}
	
	return [[self class] dataRepresentationOfType:type withCanvas:_canvas];
}

- (void)loadFromPasteboard:(NSPasteboard *)board
{
	if ([[board types] containsObject:PXLayerPboardType])
	{
		NSData *data = [board dataForType:PXLayerPboardType];
		PXLayer *layer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		[_canvas setSize:[layer size]];
		[_canvas pasteFromPasteboard:board type:PXLayerPboardType];
	}
	else
	{
		for (NSString *type in [NSImage imagePasteboardTypes])
		{
			if ([[board types] containsObject:type])
			{
				NSImage *image = [[[NSImage alloc] initWithPasteboard:board] autorelease];
				
				[_canvas setSize:NSMakeSize(ceilf([image size].width), ceilf([image size].height))];
				[_canvas pasteFromPasteboard:board type:PXNSImagePboardType];
				
				break;
			}
		}
	}
	
	if (_canvas)
	{
		[_canvas setUndoManager:[self undoManager]];
		
		// remove the auto-created main layer
		if ([[_canvas layers] count] > 1)
		{
			[_canvas removeLayerAtIndex:0];
		}
	}
	
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
}

- (void)delete:(id)sender
{
	[self.windowController delete:sender];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)aType error:(NSError **)error
{
	if (UTTypeEqual( (__bridge CFStringRef) aType, (__bridge CFStringRef) PixenImageFileType) ||
		UTTypeEqual( (__bridge CFStringRef) aType, (__bridge CFStringRef) PixenImageFileTypeOld))
	{
		self.canvas = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	}
	else if (UTTypeEqual(kUTTypeBMP, (__bridge CFStringRef) aType))
	{
		self.canvas = [[PXCanvas new] autorelease];
		
		[_canvas replaceActiveLayerWithImage:[[[NSImage alloc] initWithData:data] autorelease]];
	}
	else
	{
		NSImage *image = [[[NSImage alloc] initWithData:data] autorelease];
		
		if (!image) {
			*error = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:nil];
			return NO;
		}
		
		self.canvas = [[[PXCanvas alloc] initWithImage:image] autorelease];
	}
	
	if (_canvas)
	{
		[self.windowController setCanvas:_canvas];
		
		[[self undoManager] removeAllActions];
		[self updateChangeCount:NSChangeCleared];
		
		return YES;
	}
	
	return NO;
}

@end