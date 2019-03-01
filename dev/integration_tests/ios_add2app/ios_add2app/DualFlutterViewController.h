// Copyright 2018 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DualFlutterViewController : UIViewController

@property (readonly, weak, nonatomic) FlutterEngine* topEngine;
@property (readonly, weak, nonatomic) FlutterEngine* bottomEngine;

@end

NS_ASSUME_NONNULL_END
