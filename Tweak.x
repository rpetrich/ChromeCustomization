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

@interface _UIWebViewScrollView : UIScrollView
@end

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
			[mc.activeBVC loadJavascriptFromLocationBar:CCSettingValue(@"CCReadLaterJavaScript")];
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

%hook _UIWebViewScrollView

- (void)_endPanWithEvent:(id)event
{
	%orig();
	if (self.contentOffset.y < 0.0f) {
		MainController *mc = (MainController *)UIApp.delegate;
		BrowserViewController *bvc = mc.activeBVC;
		if (bvc.wantsFullScreenLayout) {
			[bvc showToolsMenuPopup];
		}
	}
}

%end
