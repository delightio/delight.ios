//
//  DLConstants.h
//  Delight
//
//  Created by Chris Haugli on 6/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

// Don't change the version here, it is auto-generated via a build script.
// Change it in Delight-Info.plist instead.
#define DELIGHT_VERSION_PRIVATE @"2.2.1.Private"
#define DELIGHT_VERSION_PUBLIC @"2.2.1"

#ifdef PRIVATE_FRAMEWORK
    #define DELIGHT_VERSION DELIGHT_VERSION_PRIVATE
#else
    #define DELIGHT_VERSION DELIGHT_VERSION_PUBLIC
#endif
