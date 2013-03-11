//
//  STESimpleTextDocument.h
//  SimpleTextEditor
//
//  Created by Fred Sharples on 3/11/13.
//  Copyright (c) 2013 Orange Design. All rights reserved.
//

#import <UIKit/UIKit.h>

//FS needs to be called before any other declaration to avoid compiler errors.

@protocol STESimpleTextDocumentDelegate;

@interface STESimpleTextDocument : UIDocument
@property (copy, nonatomic) NSString* documentText;

@property (weak, nonatomic) id<STESimpleTextDocumentDelegate> delegate;

@end

//FS using a delegate example
@protocol STESimpleTextDocumentDelegate <NSObject>
@optional
- (void)documentContentsDidChange:(STESimpleTextDocument*)document;
@end
