@import XCTest;

@interface E2EAppUITests : XCTestCase
@property XCUIApplication *app;
@end

@implementation E2EAppUITests

- (void)setUp {
    self.app = [XCUIApplication new];
    [self.app launch];

    self.continueAfterFailure = NO;
}

- (void)testLoginSuccessful {
    XCTAssertGreaterThan(NSProcessInfo.processInfo.environment[@"ENV_NAME"].length, 0);
    XCTAssertGreaterThan(NSProcessInfo.processInfo.environment[@"USER_TOKEN"].length, 0);

    XCUIElement *connectedLabel = self.app.staticTexts[@"Connected"];
    NSPredicate *existsPredicate = [NSPredicate predicateWithFormat:@"exists == true"];
    [self expectationForPredicate:existsPredicate evaluatedWithObject:connectedLabel handler:nil];

    [self.app.buttons[@"Login"] tap];

    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssert(connectedLabel.exists);
}

@end
