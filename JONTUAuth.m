//
//  JONTUAuth.m
//  JONTUAuth
//
//  Created by Jeremy Foo on 3/24/10.
//  Copyright 2010 THIRDLY. All rights reserved.
//
//  The MIT License
//  
//  Copyright (c) 2010 Jeremy Foo
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "JONTUAuth.h"
#import "RegexKitLite.h"

#define HTTP_USER_AGENT @"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; en-us) AppleWebKit/533.4+ (KHTML, like Gecko) Version/4.0.5 Safari/531.22.7"
#define AUTH_URL @"https://sso.wis.ntu.edu.sg/webexe88/owa/sso.asp"
#define TOKEN_URL @"https://sso.wis.ntu.edu.sg/webexe88/ntlm/sso_express.asp"
#define TOKEN_REGEX @"<input type=\"hidden\" name=\"p1\" value=\"(.*)\">\\s*<input type=\"hidden\" name=\"p2\" value=\"(.*)\">"

@implementation JONTUAuth

@synthesize cookies, user, pass, domain, studentid;

-(id)init {
    if (self = [super init]) {
        cookies = [[NSMutableArray array] retain];
		studentid = nil;
		secretToken = nil;
		auth = NO;
    }
    return self;
}

-(BOOL)auth {
	if (!auth) {
		return [self authWithRefresh:YES];
	} else {
		return auth;
	}
}

-(BOOL)authWithRefresh:(BOOL)refresh {
	// sso_express provides the real authentication variables on top of the cookies.
	// must grab p1 and p2.
	
	if (refresh) {
		[cookies removeAllObjects];
		
		NSMutableDictionary *postvalues = [NSMutableDictionary dictionary];
		
		[postvalues setValue:user forKey:@"UserName"];
		[postvalues setValue:pass forKey:@"PIN"];
		[postvalues setValue:domain forKey:@"Domain"];
		
		NSString *test = [[NSString alloc] initWithData:[self sendSyncXHRToURL:[NSURL URLWithString:AUTH_URL] postValues:postvalues] encoding:NSUTF8StringEncoding];
		
		if ([test rangeOfString:@"may be invalid or has expired"].location == NSNotFound) {
			auth = YES;
			
			NSString *finalTokenURL = [TOKEN_URL stringByReplacingOccurrencesOfString:@"://" withString:[NSString stringWithFormat:@"://%@:%@@",self.user,self.pass]];
			
			[test release], test = nil;
			test = [[NSString alloc] initWithData:[self sendSyncXHRToURL:[NSURL URLWithString:finalTokenURL] postValues:nil] encoding:NSUTF8StringEncoding];
			studentid = [[test stringByMatching:TOKEN_REGEX capture:1] retain]; // p1
			secretToken = [[test stringByMatching:TOKEN_REGEX capture:2] retain]; // p2
			
		} else {
			auth = NO;
		}
		
		[test release];
	}
	return auth;
}

-(NSMutableURLRequest *)prepareURLRequestUsing:(NSDictionary *)postValues toURL:(NSURL *)url {
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	NSMutableDictionary *mutPostValues = [postValues mutableCopy];
	[request setURL:url];
	[request setCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	
	if (postValues != nil) {
		
		NSMutableString *post = [NSMutableString string];
		if ((auth) && (![postValues valueForKey:@"p1"])) {
			[mutPostValues setObject:studentid forKey:@"p1"];
		}
		if ((auth) && (![postValues valueForKey:@"p2"])) {
			[mutPostValues setObject:secretToken forKey:@"p2"];
		}
		
		for (NSString *key in mutPostValues) {
			if ([post length] > 0) {
				[post appendString:@"&"];
			}
			[post appendFormat:@"%@=%@",key,[mutPostValues objectForKey:key]];
		}

		NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
		[request setHTTPMethod:@"POST"];
		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPBody:postData];
	}
	
	[request setValue:HTTP_USER_AGENT forHTTPHeaderField:@"User-Agent"];

	if ((auth) && ([cookies count] > 0)) {
		[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:self.cookies]];
	}
	[mutPostValues release];
	
	return [request autorelease];
}

/* 
 
 this for later implementation if we really need a run loop based way of getting url
 
-(BOOL) sendAsyncXHRToURL:(NSURL *)url postValues:(NSDictionary *)postValues {

	NSMutableURLRequest *syncRequest = [self prepareURLRequestUsing:postValues toURL:url];
	NSURLConnection *syncConnection = [[NSURLConnection alloc] initWithRequest:syncRequest delegate:self];
	BOOL status = NO;	
		
	if (syncConnection) {
		NSLog(@"Sent Request: %@ using %@", syncRequest, syncConnection);
		status = YES;
		syncRecvData = [[NSMutableData alloc] init];
		
	} else {
		status = NO;
	}
	
	return status;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	// This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
	
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
	
    // receivedData is an instance variable declared elsewhere.
	
	NSArray *pastry = [NSHTTPCookie cookiesWithResponseHeaderFields:[((NSHTTPURLResponse *)response) allHeaderFields] forURL:response.URL];
    
    for (NSHTTPCookie *cookie in pastry) {
        if ([cookie.domain hasSuffix:@".wis.ntu.edu.sg"]) {
            [cookies addObject:cookie];
        }
    }
	
    [syncRecvData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    [syncRecvData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    NSLog(@"Succeeded! Received %u bytes of data",[syncRecvData length]);
	NSLog(@"%@", [[[NSString alloc] initWithData:syncRecvData encoding:NSUTF8StringEncoding] autorelease]);
	
    // release the connection, and the data object
    [connection release];
    [syncRecvData release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [connection release];
    // receivedData is declared as a method instance elsewhere
    [syncRecvData release];
	
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	NSLog(@"Redirect recieved");
    NSURLRequest *newRequest = request;
    if (redirectResponse) {
        newRequest = nil;
    }
    return newRequest;
}

-(void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	
	NSLog(@"HELLO");
    if ([challenge previousFailureCount] == 0) {
        NSURLCredential *newCredential;
        newCredential = [NSURLCredential credentialWithUser:self.user
												   password:self.pass
												persistence:NSURLCredentialPersistenceNone];
        [[challenge sender] useCredential:newCredential
               forAuthenticationChallenge:challenge];
    } else {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        // inform the user that the user name and password
        // in the preferences are incorrect
		NSLog(@"Can't auth");
    }
}
 */

-(NSData *) sendSyncXHRToURL:(NSURL *)url postValues:(NSDictionary *)postValues {
    
	NSMutableURLRequest *request = [self prepareURLRequestUsing:postValues toURL:url];
	//	[request setTimeoutInterval:60.0];
    NSHTTPURLResponse *response;
	
	NSData *recvData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    
	if (!auth) {
		NSArray *pastry = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:[request URL]];
		
		for (NSHTTPCookie *cookie in pastry) {
			if ([cookie.domain hasSuffix:@".wis.ntu.edu.sg"]) {
				[cookies addObject:cookie];
			}
		}		
	}

	NSLog(@"Sent Request: %@", request);
	
	return recvData;
}

-(void)dealloc {
	[secretToken release], secretToken = nil;
	[cookies release], cookies = nil;
	[user release], user = nil;
	[pass release], pass = nil;
	[domain release], domain = nil;
	[studentid release], studentid = nil;
	[super dealloc];
}

@end
