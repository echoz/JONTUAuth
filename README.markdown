JONTUAuth
=========
This module helps you grab content from NTU's web services (www.ntu.edu.sg/studentlink) that requires authentication.
It requires only input from the user in the form of the network user name and password along with the domain they belong to (NTLM) and will do the rest grabbing authentication cookies as well as other information necessary to authenticate against the really hacky way NTU implemented their web services.

SSO hackiness
-------------
Aside from the usage of the module, a small note must be made about the way NTU does its so called "single sign on" services. It is plain from investigation that not a lot of thought was put into the infrastructure when it came to developing web applications. Each individual application authenticates the user via their Student ID as well as a secret token possibly generated from a combination of their password and god knows what else.

As such a "single sign on" server is needed to handle URL redirects to any service. For example, if I wanted to grab data from the Degree Audit page, I would first have to authenticate with the single sign on server using my network username and password via HTTP BASIC authentication. From there, the single sign on server will check my credentials look up my student id and the secret token, GENERATE a page that basically has javascript to submit the student id (with "NTU_" prefixed) and secret token via a form to the correct app.

Strangely, some pages do not require such a tedious process of authentication instead relying on cookies that are generated when studentlink is accessed and authenticated.

And yet, strangely, some pages will reformulate the details that were submitted via the form, removing the "NTU_" prefix for the student id and regenerate a page that submits a form using the secret token and proper student id.

Hackiness is cool, but too much just speaks volumes about the developers' abilities to create code that is abstract.

How to use JONTUAuth
====================
Prerequisite
------------
1. Add JONTUAuth.m and JONTUAuth.h to your project.
2. Add RegexKitLite if you don't already have it.
3. Add libicucore.dylib to your frameworks project.

Code
----
Here's an example of the main.m. So basically, just alloc/init a JONTUAuth object, set the user, domain and password and authenticate those to grab authentication tokens and cookies.
From there, you are free to grab pages using URLs and POST requests by putting the variables in a dictionary.

	#import <Foundation/Foundation.h>
	#import "JONTUAuth.h"

	int main (int argc, const char * argv[]) {

		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	    /**
	     * POST URL: https://sso.wis.ntu.edu.sg/webexe88/owa/sso.asp
	     * hidden inputs: t, map, pg, p2, UserName, Domain, extra
	     * input values: PIN
	     *
	     * Degree Audit: https://wish.wis.ntu.edu.sg/pls/webexe/dars_result_ro.main_display
	     * STARS Planner: https://wish.wis.ntu.edu.sg/pls/webexe/aus_stars_planner.main
	     * Print and check courses: https://wish.wis.ntu.edu.sg/pls/webexe/aus_stars_check.check_subject_web2
	     * Course Vacanccy: http://wish.wis.ntu.edu.sg/webexe/owa/aus_vacancy.check_vacancy
	     */
		JONTUAuth *auth = [[JONTUAuth alloc] init];
		[auth setUser:@"<your user>"];
		[auth setDomain:@"STUDENT"];
		[auth setPass:@"<your password>"];
	
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	//	[dict setObject:@"2010" forKey:@"acad"]; //commented out for retrival of degree audit page.
	//	[dict setObject:@"1" forKey:@"semester"];
	
		if ([auth auth]) {
			NSData *test = [auth sendSyncXHRToURL:[NSURL URLWithString:@"https://wish.wis.ntu.edu.sg/pls/webexe/dars_result_ro.main_display"] 
						 postValues:dict];
	
			NSLog(@"%@", [[[NSString alloc] initWithData:test encoding:NSUTF8StringEncoding] autorelease]);
		} else {
			NSLog(@"Can't auth");
		}
	
	
		[auth release];
	
		[pool drain];
	    return 0;
	}