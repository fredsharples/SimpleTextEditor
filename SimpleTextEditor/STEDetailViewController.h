//
//  STEDetailViewController.h
//  SimpleTextEditor
//
//  Created by Fred Sharples on 3/11/13.
//  Copyright (c) 2013 Orange Design. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STESimpleTextDocument.h"
@protocol STESimpleTextDocumentDelegate;

@interface STEDetailViewController : UIViewController

@property (strong, nonatomic) NSURL* detailItem;

@property (weak, nonatomic) IBOutlet UITextView *textView;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
