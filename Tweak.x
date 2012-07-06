#import <UIKit/UIKit2.h>
#import <CaptainHook/CaptainHook.h>

@interface BrowserViewController : UIViewController
@property (nonatomic, retain) UIView *contentArea;
- (void)handleiPhoneSwipe:(UIGestureRecognizer *)recognizer;
- (void)handleiPadSwipe:(UIGestureRecognizer *)recognizer;
- (void)loadJavascriptFromLocationBar:(NSString *)javascript;
- (void)showToolsMenuPopup;
@end

@interface ToolsPopupMenuItem : NSObject
@property (assign, nonatomic) int titleId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *uiAutomationLabel;
@property (nonatomic, retain) UITableViewCell *tableViewCell;
@property (assign, nonatomic) int tag;
@property (assign, nonatomic) BOOL active;
+ (id)menuItem:(int)titleId title:(NSString *)title uiAutomationLabel:(NSString *)automationLabel command:(int)commandId;
+ (id)menuItemWithtableViewCell:(UITableViewCell *)cell;
- (id)init;
@end

@class ToolsPopupTableViewController;

@protocol ToolsPopupTableDelegate <NSObject>
@optional
- (void)commandWasSelected:(int)commandId;
- (void)tappedBehindPopup:(ToolsPopupTableViewController *)popupTableViewController;
@end

@interface ToolsPopupTableViewController : UITableViewController
@property (assign,nonatomic) id<ToolsPopupTableDelegate> delegate;
@property (nonatomic,retain) NSMutableArray *menuItems;
@end

@class TabModel;

@interface MainController : NSObject <UIApplicationDelegate>
@property (nonatomic,retain) UIWindow *mainWindow;
@property (nonatomic,retain) BrowserViewController *mainBVC;
@property (nonatomic,retain) TabModel *mainTabModel;
@property (nonatomic,retain) BrowserViewController *otrBVC;
@property (nonatomic,retain) TabModel *otrTabModel;
@property (assign,nonatomic) BrowserViewController *activeBVC;
@property (nonatomic,retain) NSURL *externalURL;
@property (nonatomic,retain) UIWindow *window; 
@end

@interface ToolbarController : NSObject
@end

@interface WebToolbarController : ToolbarController
@property (nonatomic, retain) UIView *webToolbar;
@property (nonatomic, retain) UIButton *backButton;
@property (nonatomic, retain) UIButton *forwardButton;
@property (nonatomic, retain) UIButton *reloadButton;
@property (nonatomic, retain) UIButton *stopButton;
@property (nonatomic, retain) UIButton *starButton;
@property (nonatomic, retain) UIButton *voiceSearchButton;
@property (nonatomic, retain) UIButton *cancelButton;
@property (nonatomic, retain) UIImageView *view;
@property (nonatomic, retain) UIImageView *backgroundView;
@property (nonatomic, assign) int style;
@property (nonatomic, retain) UIButton *toolsMenuButton;
@property (nonatomic, retain) UIButton *stackButton;
@end


@interface _UIWebViewScrollView : UIScrollView
@end

@interface UIScrollViewPanGestureRecognizer : UIPanGestureRecognizer
@property (assign, nonatomic) UIScrollView *scrollView;
- (void)_centroidMovedTo:(CGPoint)point atTime:(NSTimeInterval)time;
@end

@interface TabView : UIControl
@property (nonatomic, readonly) UIButton *closeButton;
@end

#define kNavigationGestureThreshold 30.0f

static inline id CCSettingValue(NSString *key)
{
	return [[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.rpetrich.chromecustomization.plist"] objectForKey:key];
}

%hook BrowserViewController

- (void)handleiPhoneSwipe:(UIGestureRecognizer *)recognizer
{
	if ([CCSettingValue(@"CCSwipeStyle") intValue] == 1)
		[self handleiPadSwipe:recognizer];
	else {
		%orig();
		if (UIApp.statusBarHidden) {
			UIView *view = self.view;
			view.frame = [UIScreen mainScreen].bounds;
			UIView *contentArea = self.contentArea;
			[contentArea.superview bringSubviewToFront:contentArea];
			contentArea.frame = view.bounds;
		}
	}
}

- (void)handleiPadSwipe:(UIGestureRecognizer *)recognizer
{
	if ([CCSettingValue(@"CCSwipeStyle") intValue] == 2)
		[self handleiPhoneSwipe:recognizer];
	else {
		%orig();
		if (UIApp.statusBarHidden) {
			UIView *view = self.view;
			view.frame = [UIScreen mainScreen].bounds;
			UIView *contentArea = self.contentArea;
			[contentArea.superview bringSubviewToFront:contentArea];
			contentArea.frame = view.bounds;
		}
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	%orig();
	if (UIApp.statusBarHidden) {
		UIView *view = self.view;
		view.frame = [UIScreen mainScreen].bounds;
		UIView *contentArea = self.contentArea;
		contentArea.frame = view.bounds;
	}
}

%end

%hook ToolsPopupTableViewController

- (void)setMenuItems:(NSArray *)array
{
	NSMutableArray *copy = [array mutableCopy];
	if ([CCSettingValue(@"CCReadLaterJavaScript") length]) {
		ToolsPopupMenuItem *menuItem = [%c(ToolsPopupMenuItem) menuItem:-1 title:@"Read Later" uiAutomationLabel:@"Read Later" command:-1];
		if (menuItem)
			[copy insertObject:menuItem atIndex:[copy count] - 2];
	}
	ToolsPopupMenuItem *menuItem = [%c(ToolsPopupMenuItem) menuItem:-2 title:@"Fullscreen" uiAutomationLabel:@"Fullscreen" command:-2];
	if (menuItem)
		[copy insertObject:menuItem atIndex:[copy count] - 2];
	%orig(copy);
	[copy release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSArray *menuItems = self.menuItems;
	ToolsPopupMenuItem *item = [menuItems objectAtIndex:indexPath.row];
	switch (item.tag) {
		case -1: {
			MainController *mc = (MainController *)UIApp.delegate;
			NSString *javascript = CCSettingValue(@"CCReadLaterJavaScript");
			if ([javascript hasPrefix:@"javascript:"]) {
				javascript = [javascript substringFromIndex:11];
			}
			[mc.activeBVC loadJavascriptFromLocationBar:javascript];
			id<ToolsPopupTableDelegate> delegate = self.delegate;
			if ([delegate respondsToSelector:@selector(tappedBehindPopup:)])
				[delegate tappedBehindPopup:self];
			break;
		}
		case -2: {
			MainController *mc = (MainController *)UIApp.delegate;
			BrowserViewController *bvc = mc.activeBVC;
			UIView *contentArea = bvc.contentArea;
			UIViewController **toolbarController_ = CHIvarRef(bvc, toolbarController_, UIViewController *);
			// Technically we're reaching into a private c++ class inside an ivar. very ugly, but it works
			UIView *toolbarView = toolbarController_ ? (*toolbarController_).view : nil;
			if (UIApp.statusBarHidden) {
				[UIApp setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
				bvc.wantsFullScreenLayout = NO;
				[UIView animateWithDuration:0.5 animations:^{
					UIView *view = bvc.view;
					view.frame = [UIScreen mainScreen].applicationFrame;
					CGFloat height = toolbarView.frame.size.height;
					CGRect frame = view.bounds;
					frame.origin.y += height - 2.0f;
					frame.size.height -= height - 2.0f;
					contentArea.frame = frame;
					frame.origin.y = 0.0f;
					frame.size.height = height;
					toolbarView.frame = frame;
				}];
			} else {
				[UIApp setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
				bvc.wantsFullScreenLayout = YES;
				[UIView animateWithDuration:0.5 animations:^{
					UIView *view = bvc.view;
					view.frame = [UIScreen mainScreen].bounds;
					contentArea.frame = view.bounds;
					CGRect frame = toolbarView.frame;
					frame.origin.y -= frame.size.height - 2.0f;
					toolbarView.frame = frame;
				}];
			}
			id<ToolsPopupTableDelegate> delegate = self.delegate;
			if ([delegate respondsToSelector:@selector(tappedBehindPopup:)])
				[delegate tappedBehindPopup:self];
			break;
		}
		default:
			%orig();
	}
}

%end

static BOOL allowBackGesture;
static BOOL allowForwardGesture;

@interface UIScrollView (chromeCustomization)
- (void)chromeCustomization_updateBackForwardUI;
@end

@implementation UIScrollView (chromeCustomization)
- (void)chromeCustomization_updateBackForwardUI
{
}
@end

%hook _UIWebViewScrollView

- (id)initWithFrame:(CGRect)frame
{
	if ((self = %orig())) {
		self.alwaysBounceHorizontal = YES;
	}
	return self;
}

- (void)chromeCustomization_updateBackForwardUI
{
	%orig();
	UIWebView *webView = (UIWebView *)self.superview;
	if ([webView isKindOfClass:[UIWebView class]]) {
		CATransform3D transform = CATransform3DIdentity;
		transform.m34 = 1.0 / -800;
		CGPoint offset = self.contentOffset;
		if (allowBackGesture && (offset.x < - kNavigationGestureThreshold)) {
			transform = CATransform3DRotate(transform, -10.0f * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
		} else if (allowForwardGesture && (offset.x > self.contentSize.width - self.bounds.size.width + kNavigationGestureThreshold)) {
			transform = CATransform3DRotate(transform, 10.0f * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
		}
		CALayer *layer = self.layer;
		CATransform3D currentTransform = layer.sublayerTransform;
		if (!CATransform3DEqualToTransform(currentTransform, transform)) {
			layer.sublayerTransform = transform;
			CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"sublayerTransform"];
			animation.fromValue = [NSValue valueWithCATransform3D:currentTransform];
			animation.toValue = [NSValue valueWithCATransform3D:transform];
			animation.duration = 0.2;
			animation.removedOnCompletion = YES;
			[layer addAnimation:animation forKey:@"sublayerTransform"];
		}
	}
}

- (void)_endPanWithEvent:(id)event
{
	%orig();
	CGPoint offset = self.contentOffset;
	UIWebView *webView = (UIWebView *)self.superview;
	if ([webView isKindOfClass:[UIWebView class]]) {
		MainController *mc = (MainController *)UIApp.delegate;
		BrowserViewController *bvc = mc.activeBVC;
		WebToolbarController **toolbarController_ = CHIvarRef(bvc, toolbarController_, WebToolbarController *);
		if (allowBackGesture && (offset.x < - kNavigationGestureThreshold)) {
			[(*toolbarController_).backButton sendActionsForControlEvents:UIControlEventTouchUpInside];
		} else if (allowForwardGesture && (offset.x > self.contentSize.width - self.bounds.size.width + kNavigationGestureThreshold)) {
			[(*toolbarController_).forwardButton sendActionsForControlEvents:UIControlEventTouchUpInside];
		} else if (offset.y < 0.0f) {
			MainController *mc = (MainController *)UIApp.delegate;
			BrowserViewController *bvc = mc.activeBVC;
			if (bvc.wantsFullScreenLayout) {
				[bvc showToolsMenuPopup];
			}
		}
	}
	// Reset transform
	CALayer *layer = self.layer;
	CATransform3D currentTransform = layer.sublayerTransform;
	if (!CATransform3DEqualToTransform(currentTransform, CATransform3DIdentity)) {
		layer.sublayerTransform = CATransform3DIdentity;
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"sublayerTransform"];
		animation.fromValue = [NSValue valueWithCATransform3D:currentTransform];
		animation.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
		animation.duration = 0.2;
		animation.removedOnCompletion = YES;
		[layer addAnimation:animation forKey:@"sublayerTransform"];
	}
}

%end

%hook UIScrollViewPanGestureRecognizer

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIScrollView *scrollView = self.scrollView;
	CGPoint contentOffset = scrollView.contentOffset;
	MainController *mc = (MainController *)UIApp.delegate;
	BrowserViewController *bvc = mc.activeBVC;
	WebToolbarController **toolbarController_ = CHIvarRef(bvc, toolbarController_, WebToolbarController *);
	if (toolbarController_) {
		allowBackGesture = (contentOffset.x == 0.0f) && (*toolbarController_).backButton.enabled;
		allowForwardGesture = (contentOffset.x == scrollView.contentSize.width - scrollView.bounds.size.width) && (*toolbarController_).forwardButton.enabled;
	} else {
		allowBackGesture = NO;
		allowForwardGesture = NO;
	}
	%orig();
}

- (void)_centroidMovedTo:(CGPoint)to atTime:(NSTimeInterval)time
{
	%orig();
	[self.scrollView chromeCustomization_updateBackForwardUI];
}

%end

%hook TabView

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	%orig();
	NSSet *viewTouches = [event touchesForView:self];
	if ([viewTouches count] == 1) {
		UITouch *touch = [viewTouches anyObject];
		CGPoint point = [touch locationInView:self];
		if (point.y < -10.0f) {
			[[self closeButton] sendActionsForControlEvents:UIControlEventTouchUpInside];
		}
	}
}

%end

static NSDictionary *hostnameMap;

@interface ChromeCustomizationBlockProtocol : NSURLProtocol
@end

@implementation ChromeCustomizationBlockProtocol


+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	// Allow all frame loads to go through, be concerned only with assets
	NSString *accept = [request valueForHTTPHeaderField:@"Accept"];
	if ([accept hasPrefix:@"text/html,"])
		return NO;
	// Load all requests that don't have a referer
	NSString *referer = [request valueForHTTPHeaderField:@"Referer"];
	if (![referer length])
		return NO;
	NSString *refererHost = [[NSURL URLWithString:referer] host];
	// Load all requests to the same hostname
	NSString *requestHost = request.URL.host;
	if ([refererHost isEqualToString:requestHost])
		return NO;
	// Lookup request host data by recursively removing the first domain component
	NSString *currentRequestHost = requestHost;
	if (!currentRequestHost)
		return NO;
	NSDictionary *requestHostData;
	for (;;) {
		requestHostData = (NSDictionary *)CFDictionaryGetValue((CFDictionaryRef)hostnameMap, currentRequestHost);
		if (requestHostData)
			break;
		NSInteger index = [currentRequestHost rangeOfString:@"."].location;
		if (index == NSNotFound)
			return NO;
		currentRequestHost = [currentRequestHost substringFromIndex:index + 1];
	}
	// Allow contacting sister domains, even if they would normally block
	if (CFDictionaryGetValue((CFDictionaryRef)requestHostData, referer))
		return NO;
	NSLog(@"ChromeCustomization: Blocked %@ from %@", refererHost, requestHost);
	return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    // Requests are only canonical with respect to themselves
    return [[request copy] autorelease];
}

+ (BOOL) requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [a isEqual:b];
}

- (void)startLoading
{
	[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:nil]];
}

- (void)stopLoading
{
}

@end

%hook UIApplication

- (void)_reportAppLaunchFinished
{
	NSDictionary *blank = [NSDictionary dictionary];
	NSDictionary *facebook = [NSDictionary dictionaryWithObjectsAndKeys:
		(id)kCFBooleanTrue, @"facebook.com",
		(id)kCFBooleanTrue, @"fbcdn.net",
		nil];
	NSDictionary *twitter = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"twitter.com"];
	NSDictionary *meebo = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"meebo.com"];
	NSDictionary *chartbeat = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"chartbeat.com"];
	NSDictionary *postup = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"tweetup.com"];
	NSDictionary *conduit = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"conduit.com"];
	NSDictionary *addthis = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"addthis.com"];
	NSDictionary *woopra = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"woopra.com"];
	NSDictionary *getclicky = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"getclicky.com"];
	NSDictionary *linkedin = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"linkedin.com"];
	NSDictionary *dzone = [NSDictionary dictionaryWithObject:(id)kCFBooleanTrue forKey:@"dzone.com"];
	hostnameMap = [[NSDictionary dictionaryWithObjectsAndKeys:
		facebook, @"facebook.com",
		facebook, @"facebook.net",
		facebook, @"fbcdn.net",
		blank, @"fbshare.me",
		twitter, @"platform.twitter.com",
		twitter, @"twitter.com",
		blank, @"disqus.com",
		blank, @"digg.com",
		meebo, @"meebo.com",
		meebo, @"meebocdn.net",
		blank, @"publitweet.com",
		blank, @"lijit.com",
		chartbeat, @"chartbeat.com",
		chartbeat, @"chartbeat.net",
		blank, @"causes.com",
		postup, @"tweetup.com",
		postup, @"postup.com",
		conduit, @"conduit.com",
		conduit, @"conduit-banners.com",
		blank, @"quantserve.com",
		blank, @"google-analytics.com",
  		blank, @"gravatar.com",
		blank, @"google.com/buzz",
		blank, @"google.com/cse",
		blank, @"google.com/friendconnect",
		blank, @"stats.wordpress.com",
		blank, @"scorecardresearch.com",
		blank, @"speakertext.com",
		blank, @"snap.com" ,
		blank, @"snapabug.com",
		blank, @"revsci.net",
		blank, @"badgeville.com",
		blank, @"chomp.com",
		blank, @"wibiya.com",
		addthis, @"addthis.com",
		addthis, @"addthiscdn.com",
		woopra, @"woopra.com",
		woopra, @"woopra-ns.com",
		blank, @"apture.com/js/apture.js",
		blank, @"js-kit.com",
		blank, @"yaptor.com",
		blank, @"tweetmeme.com",
		getclicky, @"get-clicky.com",
		getclicky, @"getclicky.com",
		blank, @"fmpub.net",
		blank, @"typekit.com",
		blank, @"buysellads.com",
		blank, @"sharethis.com",
		blank, @"outbrain.com",
		blank, @"adtech.us",
		blank, @"mar.gy",
		blank, @"mixpanel.com",
		blank, @"kissmetrics.com",
		blank, @"viglink.com",
		blank, @"fyre.co",
		blank, @"assistly.com",
		blank, @"stumbleupon.com",
		blank, @"delicious.com",
		blank, @"uservoice.com",
		linkedin, @"platform.linkedin.com",
		dzone, @"widgets.dzone.com",
		blank, @"envolve.com",
		blank, @"vkontakte.ru",
		blank, @"apis.google.com/js/plusone",
		blank, @"amung.us",
		nil] retain];
	[ChromeCustomizationBlockProtocol registerClass:[ChromeCustomizationBlockProtocol class]];
	%orig;
}

%end
