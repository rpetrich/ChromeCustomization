#import <Foundation/Foundation.h>

__attribute__((visibility("hidden")))
@interface CCTrackingPrivacyList : NSObject {
@private
	NSDictionary *allowedDomainRules;
	NSDictionary *blockedDomainRules;
	NSSet *blockedDomains;
	NSSet *blockedRules;
}
- (id)initWithContentsOfFile:(NSString *)filePath;
- (BOOL)URLPassesFilter:(NSURL *)url;
@end

