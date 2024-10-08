//
//  ACEModeNames.h
//  ACEView
//
//  Created by Michael Robinson on 2/12/12.
//  Copyright (c) 2012 Code of Interest. All rights reserved.
//


#if __has_include(<ACEView/ACEModes.h>)
#import <ACEView/ACEModes.h>
#else
#import "ACEModes.h"
#endif

#if __has_feature(objc_generics)
#define OF_NSSTRING <NSString *>
#else
#define OF_NSSTRING
#endif

/** Class providing methods to:

 - convert ACE mode names used internally to to their human-readable counterparts and vise-versa.
 - Convert ACEmode constants into their ACE theme or human-readable ACE mode names.

 */

@interface ACEModeNames : NSObject { }

/**---------------------------------------------------------------------------------------
 * @name Class Methods
 *  ---------------------------------------------------------------------------------------
 */

/** Return an array of ACE mode names.

 @return Array of ACE mode names.
 */
+ (NSArray OF_NSSTRING *) modeNames;
/** Return an array of human-readable ACE mode names.

 @return Array of human-readable ACE mode names.
 */
+ (NSArray OF_NSSTRING *) humanModeNames;

/** Return the ACE mode name for a given ACEmode constant.

 @param mode The ACEMode constant to be converted.
 @return The ACE mode name corresponding to the given ACEMode constant.
 */
+ (NSString *) nameForMode:(ACEMode)mode;
/** Return the human-readable ACE mode name for a given ACEMode constant.

 @param mode The ACEMode constant to be converted.
 @return The human-readable ACE mode name corresponding to the given ACEMode constant.
 */
+ (NSString *) humanNameForMode:(ACEMode)mode;

@end
