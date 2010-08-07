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

#import "NTUAuth.h"

#define HTTP_USER_AGENT @"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; en-us) AppleWebKit/533.4+ (KHTML, like Gecko) Version/4.0.5 Safari/531.22.7"
#define AUTH_URL @"https://sso.wis.ntu.edu.sg/webexe88/owa/sso.asp"

@implementation NTUAuth

@synthesize cookies, user, pass, domain, studentid;

-(id)init {
    if (self = [super init]) {
        cookies = [[NSMutableArray array] retain];
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
	// todo, capture p1 and p2 dynamically along with student id
	
	if (refresh) {
		[cookies removeAllObjects];
		
		NSMutableDictionary *postvalues = [NSMutableDictionary dictionary];
		
		[postvalues setValue:user forKey:@"UserName"];
		[postvalues setValue:pass forKey:@"PIN"];
		[postvalues setValue:domain forKey:@"Domain"];
		
		NSString *test = [[NSString alloc] initWithData:[self sendAsyncXHRToURL:AUTH_URL PostValues:postvalues] encoding:NSUTF8StringEncoding];
		
		if ([test rangeOfString:@"may be invalid or has expired"].location == NSNotFound) {
			auth = YES;
		} else {
			auth = NO;
		}		
	}
	
	return auth;
}

-(NSData *) sendAsyncXHRToURL:(NSString *)url PostValues:(NSDictionary *)postValues {
    
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSHTTPURLResponse *response;
    
	if (postValues != nil) {
        		
		NSMutableString *post = [NSMutableString string];
		if (auth) {
			[post appendFormat:@"%@=%@",@"p1",studentid];
		}
		
		for (NSString *key in postValues) {
			if ([post length] > 0) {
				[post appendString:@"&"];
			}
			[post appendFormat:@"%@=%@",key,[postValues objectForKey:key]];
		}
		
		NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
		[request setHTTPMethod:@"POST"];
		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setValue:HTTP_USER_AGENT forHTTPHeaderField:@"User-Agent"];
		[request setHTTPBody:postData];
		
		if ((auth) && ([cookies count] > 0)) {
			NSLog(@"Submitted auth cookies");
			[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:self.cookies]];
		}
		
	}
	
	[request setURL:[NSURL URLWithString:url]];
	
	NSData *recvData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    
    NSArray *pastry = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:[request URL]];
    
    for (NSHTTPCookie *cookie in pastry) {
        if ([cookie.domain hasSuffix:@".wis.ntu.edu.sg"]) {
            [cookies addObject:cookie];
        }
    }

	NSLog(@"Sent Request: %@", request);
	
	[request release];
	
	return recvData;
}

-(void)dealloc {
	[cookies release], cookies = nil;
	[user release], user = nil;
	[pass release], pass = nil;
	[domain release], domain = nil;
	[studentid release], studentid = nil;
	[super dealloc];
}

@end
