#import "CCTrackingPrivacyList.h"

// TODO: Use Robin-Karp for fast matching
// TODO: Support wildcard matching

#ifndef DEBUG
#define NSLog(...) do { } while(0)
#endif

@implementation CCTrackingPrivacyList

#define gcfib CFStringGetCharacterFromInlineBuffer

// Fastish search for newlines
static inline NSRange CCFindCompoundNewline(CFStringInlineBuffer *buffer, NSRange searchRange)
{
	CFIndex position = searchRange.location;
	CFIndex end = searchRange.location + searchRange.length;
	while (position < end) {
		switch (gcfib(buffer, position)) {
			case '\n':
				return (NSRange){ position, 1 };
			case '\r': {
				bool hasNewlineAfter = (position != end - 1) && (gcfib(buffer, position + 1) == '\n');
				return (NSRange){ position, hasNewlineAfter ? 2 : 1 };
			}
			default:
				position++;
		}
	}
	return (NSRange){ NSNotFound, -1 };
}

static inline NSInteger CCFindCharacter(CFStringInlineBuffer *buffer, NSRange searchRange, unichar character)
{
	CFIndex position = searchRange.location;
	CFIndex end = searchRange.location + searchRange.length;
	while (position < end) {
		if (gcfib(buffer, position) == character)
			return position;
		position++;
	}
	return NSNotFound;
}

- (id)initWithContentsOfFile:(NSString *)filePath
{
	if ((self = [super init])) {
		NSString *text = [[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL] stringByAppendingString:@"\r\n"];
		if (!text) {
			// Can't read file :(
			[self release];
			return nil;
		}
		NSRange searchRange = NSMakeRange(0, [text length]);
		CFStringInlineBuffer buffer;
		CFStringInitInlineBuffer((CFStringRef)text, &buffer, (CFRange){ searchRange.location, searchRange.length });
		NSRange newlineRange = CCFindCompoundNewline(&buffer, searchRange);
		if (newlineRange.location == NSNotFound) {
			// File only has one line :(
			[self release];
			return nil;
		}
		NSString *firstString = [text substringWithRange:NSMakeRange(0, newlineRange.location)];
		if (!([firstString isEqualToString:@"FilterList"] || [firstString isEqualToString:@"msFilterList"])) {
			// Not a filter file :(
			[self release];
			return nil;
		}
		NSMutableDictionary *_allowedDomainRules = [NSMutableDictionary dictionary];
		NSMutableDictionary *_blockedDomainRules = [NSMutableDictionary dictionary];
		NSMutableSet *_blockedDomains = [NSMutableSet set];
		NSMutableSet *_blockedRules = [NSMutableSet set];
		searchRange.location += newlineRange.location + newlineRange.length;
		searchRange.length -= newlineRange.location + newlineRange.length;
		NSRange textRange;
		do {
			newlineRange = CCFindCompoundNewline(&buffer, searchRange);
			if (newlineRange.location == NSNotFound)
				textRange = searchRange;
			else {
				textRange = (NSRange){ searchRange.location, newlineRange.location - searchRange.location };
				searchRange.location += newlineRange.length + newlineRange.location - searchRange.location;
				searchRange.length -= newlineRange.length + newlineRange.location - searchRange.location;
			}
			if (textRange.length >= 3) {
				switch (gcfib(&buffer, textRange.location)) {
					case '+':
						// Allow Domain Rule
						if ((gcfib(&buffer, textRange.location + 1) == 'd') && (gcfib(&buffer, textRange.location + 2) == ' ')) {
							textRange.location += 3;
							textRange.length -= 3;
							NSInteger space = CCFindCharacter(&buffer, textRange, ' ');
							if (space != NSNotFound) {
								NSString *domain = [text substringWithRange:(NSRange){ textRange.location, space - textRange.location }];
								NSString *rule = [text substringWithRange:(NSRange){ space + 1, textRange.location + textRange.length - space - 1}];
								NSLog(@"Allow rule: %@ for domain: %@", rule, domain);
								NSMutableSet *set = [_allowedDomainRules objectForKey:domain];
								if (!set) {
									set = [NSMutableSet set];
									[_allowedDomainRules setObject:set forKey:domain];
								}
								[set addObject:rule];
							}
						}
					case '-':
						switch (gcfib(&buffer, textRange.location + 1)) {
							// Block Domain Rule
							case 'd':
								if (gcfib(&buffer, textRange.location + 2) == ' ') {
									textRange.location += 3;
									textRange.length -= 3;
									NSInteger space = CCFindCharacter(&buffer, textRange, ' ');
									if (space != NSNotFound) {
										NSString *domain = [text substringWithRange:(NSRange){ textRange.location, space - textRange.location }];
										NSString *rule = [text substringWithRange:(NSRange){ space + 1, textRange.location + textRange.length - space - 1}];
										NSLog(@"Block rule: %@ for domain: %@", rule, domain);
										NSMutableSet *set = [_allowedDomainRules objectForKey:domain];
										if (!set) {
											set = [NSMutableSet set];
											[_blockedDomainRules setObject:set forKey:domain];
										}
										[set addObject:rule];
									} else {
										NSString *domain = [text substringWithRange:textRange];
										NSLog(@"Block domain: %@", domain);
										[_blockedDomains addObject:domain];
									}
								}
								break;
							// Block All Rule
							case ' ': {
								textRange.location += 2;
								textRange.length -= 2;
								NSString *rule = [text substringWithRange:textRange];
								NSLog(@"Block rule: %@", rule);
								[_blockedRules addObject:rule];
								break;
							}
						}
				}
			}
		} while (newlineRange.location != NSNotFound);
		allowedDomainRules = [_allowedDomainRules copy];
		blockedDomainRules = [_blockedDomainRules copy];
		blockedDomains = [_blockedDomains copy];
		blockedRules = [_blockedRules copy];
	}
	return self;
}

- (void)dealloc
{
	[allowedDomainRules release];
	[blockedDomainRules release];
	[blockedDomains release];
	[blockedRules release];
	[super dealloc];
}

- (NSSet *)hostVariantsForURL:(NSURL *)url
{
	NSString *host = [[url host] lowercaseString];
	NSString *previousHost = host;
	NSMutableSet *result = [NSMutableSet set];
	NSRange range = (NSRange){ 0, [host length] };
	if (range.length == 0)
		return result;
	CFStringInlineBuffer buffer;
	CFStringInitInlineBuffer((CFStringRef)host, &buffer, (CFRange){ 0, range.length });
	NSInteger index;
	while ((index = CCFindCharacter(&buffer, range, '.')) != NSNotFound) {
		// Only add the previous host so that we always skip the tld
		if (previousHost)
			[result addObject:previousHost];
		range.length = (range.length + range.location) - (index + 1);
		range.location = index + 1;
		previousHost = [host substringWithRange:range];
		if (!previousHost)
			break;
	}
	// Special case to not consider co.<tld> a host variant for *.co.<tld>
	if (previousHost && ([previousHost length] <= 3)) {
		[result removeObject:[@"co." stringByAppendingString:previousHost]];
		// And other weird cases like .ar that only give out *.com.ar and whatnot
		[result removeObject:[@"com." stringByAppendingString:previousHost]];
		[result removeObject:[@"net." stringByAppendingString:previousHost]];
		[result removeObject:[@"org." stringByAppendingString:previousHost]];
	}
	return result;
}

- (BOOL)URLString:(NSString *)urlString matchesRuleInSet:(NSSet *)rules
{
	if (!urlString)
		return NO;
	for (NSString *rule in rules)
		if ([urlString rangeOfString:rule].location != NSNotFound)
			return YES;
	return NO;
}

- (BOOL)URLPassesFilter:(NSURL *)url
{
	NSString *urlString = [url absoluteString];
	for (NSString *hostVariant in [self hostVariantsForURL:url]) {
		NSSet *allowedRules = (NSSet *)CFDictionaryGetValue((CFDictionaryRef)allowedDomainRules, hostVariant);
		if ([self URLString:urlString matchesRuleInSet:allowedRules])
			return YES;
		if ([blockedDomains containsObject:hostVariant])
			return NO;
		NSSet *localBlockedRules = (NSSet *)CFDictionaryGetValue((CFDictionaryRef)blockedDomainRules, hostVariant);
		if ([self URLString:urlString matchesRuleInSet:localBlockedRules])
			return NO;
	}
	return ![self URLString:urlString matchesRuleInSet:blockedRules];
}

@end
