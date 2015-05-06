//
//  SocialLoginViewController.m
//  cloudmine-ios
//
//  Copyright (c) 2012 CloudMine, LLC. All rights reserved.
//  See LICENSE file included with SDK for details.
//

#import "CMUIViewController+Modal.h"
#import "CMSocialLoginViewController.h"
#import "CMWebService.h"
#import "CMStore.h"
#import "CMUser.h"

@interface CMSocialLoginViewController ()
{
    NSMutableData* responseData;
    UIView* pendingLoginView;
    UIActivityIndicatorView* activityView;
}

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UINavigationBar *navigationBar;

- (void)processAccessTokenWithData:(NSData*)data;

@end

@implementation CMSocialLoginViewController

- (id)initForService:(NSString *)service appID:(NSString *)appID apiKey:(NSString *)apiKey user:(CMUser *)user params:(NSDictionary *)params
{
    self = [super init];
    if (self)
    {
        _user = user;
        _targetService = service;
        _appID = appID;
        _apiKey = apiKey;
        _params = params;
        _challenge = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _webView = [[UIWebView alloc] initWithFrame:self.view.frame];
    _webView.scalesPageToFit = YES;
    _webView.delegate = self;
    [self.view addSubview:_webView];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(UIStatusBarStyle)preferredStatusBarStyle{
	return UIStatusBarStyleDefault;
}
- (void)viewWillAppear:(BOOL)animated;
{
    // Clear Cookies
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	storage.cookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
//    for (cookie in [storage cookies]) {
//        [storage deleteCookie:cookie];
//    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (self.isModal)
    {
		NSInteger navHeight = 44;
		if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) navHeight = 64;

        self.webView.frame = CGRectMake(0, navHeight, self.view.frame.size.width, self.view.frame.size.height - navHeight);
        self.navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, navHeight)];
        UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:@"Login"];//self.targetService];
        navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(dismiss)];
		[navigationItem.leftBarButtonItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
																  [UIColor colorWithRed:255/255.f green:66/255.f blue:60/255.f alpha:1], UITextAttributeTextColor,
																  nil] forState:UIControlStateNormal];
        self.navigationBar.items = @[navigationItem];
        
        //
        // Set the tint color of our navigation bar to match the tint of the
        // view controller's navigation bar that is responsible for presenting
        // us modally.
        //
		[self.navigationBar setTranslucent:NO];
		CGRect frame = [self.navigationBar frame];
		frame.size.height = navHeight;
		[self.navigationBar setFrame:frame];
		if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
			[self setNeedsStatusBarAppearanceUpdate];
		}
		if ([self.navigationBar respondsToSelector:@selector(setShadowImage:)]) {
			[self.navigationBar setBackgroundImage:[[UIImage alloc] init] forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
			[self.navigationBar setShadowImage:[UIImage new]];
		}
		[self.navigationBar setBackgroundImage:[UIImage imageNamed:(44==navHeight)?@"nav-back.png":@"nav-back-64.png"] forBarMetrics:UIBarMetricsDefault];
		if ([self.navigationBar respondsToSelector:@selector(setBackgroundColor:)]) {
			[self.navigationBar setBackgroundColor:[UIColor colorWithRed:40/255.f green:179/255.f blue:191/255.f alpha:1]];
		}
		if ([self.navigationBar respondsToSelector:@selector(setBarTintColor:)]) {
			[self.navigationBar setBarTintColor:[UIColor colorWithRed:40/255.f green:179/255.f blue:191/255.f alpha:1]];
		}
		
        if ([self.presentingViewController respondsToSelector:@selector(navigationBar)])
        {
            UIColor *presentingTintColor = ((UINavigationController *)self.presentingViewController).navigationBar.tintColor;
            self.navigationBar.tintColor = presentingTintColor;
        }
        [self.view addSubview:self.navigationBar];
    }
    else
    {
        if (self.navigationBar)
        {
            [self.navigationBar removeFromSuperview];
            self.navigationBar = nil;
        }
    }
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/app/%@/account/social/login?service=%@&apikey=%@&challenge=%@",
                                    CM_BASE_URL, _appID, _targetService, _apiKey, _challenge];
    
    //Link accounts if user is logged in. If you don't want the accounts linked, log out the user.
    if ( _user && _user.isLoggedIn)
        urlStr = [urlStr stringByAppendingFormat:@"&session_token=%@", _user.token];
    
    // Add any additional params to the request
    if ( _params != nil && [_params count] > 0 ) {
        for (NSString *key in _params) {
            urlStr = [urlStr stringByAppendingFormat:@"&%@=%@", key, [_params valueForKey:key]];
        }
    }
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]]];
}


- (void)processAccessTokenWithData:(NSData*)data;
{
    NSLog(@"%@", data);
}


#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView;
{
    
}

- (void)webViewDidFinishLoad:(UIWebView *)webView;
{
    
    NSString *currentURLstr = [[[webView request] URL] absoluteString];

//	NSLog(@"%@", currentURLstr);
        
    NSString *baseURLstr = [NSString stringWithFormat:@"%@/app/%@/account/social/login/complete", CM_BASE_URL, _appID];
    
    if (currentURLstr.length >= baseURLstr.length) {
        NSString *comparableRequestStr = [currentURLstr substringToIndex:baseURLstr.length];

        // If at the challenge complete URL, prepare and send GET request for session token info
        if ([baseURLstr isEqualToString:comparableRequestStr]) {
        
            // Display pending login view during request/processing
            pendingLoginView = [[UIView alloc] initWithFrame:self.webView.bounds];
            pendingLoginView.center = self.webView.center;
            pendingLoginView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
            activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            activityView.frame = CGRectMake(pendingLoginView.frame.size.width / 2, pendingLoginView.frame.size.height / 2, activityView.bounds.size.width, activityView.bounds.size.height);
            activityView.center = self.webView.center;
            [pendingLoginView addSubview:activityView];
            [activityView startAnimating];
            [self.view addSubview:pendingLoginView];
            [self.view bringSubviewToFront:pendingLoginView];
            
            // Call WebService function to establish GET for session token and user profile
            [self.delegate cmSocialLoginViewController:self completeSocialLoginWithChallenge:_challenge];
        }
    }
    ///
    /// Else, we got some sort of error. Handle responsibly.
    //TODO: Add in.
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"WebView error. This sometimes happens when the User is logging into a social network where cookies have been stored and is already logged in. %@", [error description]);
    [self.delegate cmSocialLoginViewController:self completeSocialLoginWithChallenge:_challenge];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

- (void)dismiss
{
    [self dismissModalViewControllerAnimated:YES];
}


@end
