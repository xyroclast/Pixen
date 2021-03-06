//
//  PXColor.h
//  Pixen
//
//  Copyright 2012 Pixen Project. All rights reserved.
//

#import <AppKit/AppKit.h>

typedef struct {
	uint8_t r, g, b, a;
} PXColor;

PXColor PXGetBlackColor(void);
PXColor PXGetClearColor(void);

PXColor PXColorMake(uint8_t r, uint8_t g, uint8_t b, uint8_t a);

PXColor PXColorFromNSColor(NSColor *color);
NSColor *PXColorToNSColor(PXColor color);

BOOL PXColorEqualsColor(PXColor color, PXColor otherColor);
int PXColorDistanceToColor(PXColor color, PXColor otherColor);

PXColor PXColorBlendWithColor(PXColor bottomColor, PXColor topColor);
