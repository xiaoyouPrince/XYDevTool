//
//  ACEThemeNames.h
//  ACEView
//
//  Created by Michael Robinson on 2/12/12.
//  Copyright (c) 2012 Code of Interest. All rights reserved.
//

#if __has_include(<ACEView/ACEThemes.h>)
#import <ACEView/ACEThemes.h>
#else
#import "ACEThemes.h"
#endif

#if __has_feature(objc_generics)
#define OF_NSSTRING <NSString *>
#else
#define OF_NSSTRING
#endif

/** Class providing methods to:

 - convert ACE theme names used internally to to their human-readable counterparts and vise-versa.
 - Convert ACETheme constants into their ACE theme or human-readable ACE theme names.

 */

@interface ACEThemeNames : NSObject { }

/**---------------------------------------------------------------------------------------
 * @name Class Methods
 *  ---------------------------------------------------------------------------------------
 */

/** Return an array of ACE theme names.

 @return Array of ACE theme names.
 */
+ (NSArray OF_NSSTRING *) themeNames;
/** Return an array of human-readable ACE theme names.

 @return Array of human-readable ACE theme names.
 */
+ (NSArray OF_NSSTRING *) humanThemeNames;

/** Return the ACE theme name for a given ACETheme constant.

 @param theme The ACETheme constant to be converted.
 @return The ACE theme name corresponding to the given ACETheme constant.
 */
+ (NSString *) nameForTheme:(ACETheme)theme;
/** Return the human-readable ACE theme name for a given ACETheme constant.

 @param theme The ACETheme constant to be converted.
 @return The human-readable ACE theme name corresponding to the given ACETheme constant.
 */
+ (NSString *) humanNameForTheme:(ACETheme)theme;

@end
