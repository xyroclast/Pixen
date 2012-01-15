//
//  PXAnimationBackgroundView.h
//  Pixen
//
//  Copyright 2005-2012 Pixen Project. All rights reserved.
//

@interface PXAnimationBackgroundView : NSView
{
	NSGradient *_horizontalGradient;
    NSScrollView *_filmStrip;
}

@property (nonatomic, retain) IBOutlet NSScrollView *filmStrip;

@end
