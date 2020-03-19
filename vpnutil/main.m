//
//  main.m
//  vpnutil
//
//  Created by Alexandre Colucci on 07.07.2018.
//  Copyright © 2018 Timac. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ACDefines.h"
#import "ACNEService.h"
#import "ACNEServicesManager.h"

static void PrintUsage()
{
	fprintf(stderr, "Usage: vpnutil [start|stop|info] [VPN name]\n");
	fprintf(stderr, "Examples:\n");
	fprintf(stderr, "\t To start the VPN called 'MyVPN':\n");
	fprintf(stderr, "\t vpnutil start MyVPN\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "\t To stop the VPN called 'MyVPN':\n");
	fprintf(stderr, "\t vpnutil stop MyVPN\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "Copyright © 2018 Alexandre Colucci\nblog.timac.org\n");
	fprintf(stderr, "\n");

	exit(1);
}


static NSString * GetDescriptionForSCNetworkConnectionStatus(SCNetworkConnectionStatus inStatus)
{
	switch(inStatus)
	{
		case kSCNetworkConnectionInvalid:
		{
			return @"Invalid";
		}
		break;

		case kSCNetworkConnectionDisconnected:
		{
			return @"Disconnected";
		}
		break;

		case kSCNetworkConnectionConnecting:
		{
			return @"Connecting";
		}
		break;

		case kSCNetworkConnectionConnected:
		{
			return @"Connected";
		}
		break;

		case kSCNetworkConnectionDisconnecting:
		{
			return @"Disconnecting";
		}
		break;

		default:
		{
			return @"Unknown";
		}
		break;
	}

	return @"Unknown";
};

int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		if (argc != 3)
		{
			PrintUsage();
		}
		// Do we want to start or stop the service?
		BOOL shouldStartService = NO;
		BOOL requireInfo = NO;
		NSString *parameter1 = [NSString stringWithUTF8String:argv[1]];
		if ([parameter1 isEqualToString:@"start"])
		{
			shouldStartService = YES;
		}
		else if ([parameter1 isEqualToString:@"stop"])
		{
			shouldStartService = NO;
		}
    else if ([parameter1 isEqualToString:@"info"])
    {
      shouldStartService = NO;
			requireInfo = YES;
    }
		else
		{
			PrintUsage();
		}

		// Get the VPN name?
		NSString *vpnName = [NSString stringWithUTF8String:argv[2]];
		if ([vpnName length] <= 0)
		{
			PrintUsage();
		}

		// Since this is a command line tool, we manually run an NSRunLoop
		__block ACNEService *foundNEService = NULL;
		__block BOOL keepRunning = YES;

		// Make sure that the ACNEServicesManager singleton is created and load the configurations
		[[ACNEServicesManager sharedNEServicesManager] loadConfigurationsWithHandler:^(NSError * error)
		{
			if(error != nil)
			{
				NSLog(@"Failed to load the configurations - %@", error);
			}

			NSArray <ACNEService*>* neServices = [[ACNEServicesManager sharedNEServicesManager] neServices];
			if([neServices count] <= 0)
			{
				NSLog(@"Could not find any VPN");
			}

			for(ACNEService *neService in neServices)
			{
				if([neService.name isEqualToString:vpnName])
				{
					foundNEService = neService;
					break;
				}
			}

			if(!foundNEService)
			{
				// Stop running the NSRunLoop
				keepRunning = NO;
			}
		}];

		CFAbsoluteTime startWaiting = CFAbsoluteTimeGetCurrent();

		//
		// Wait:
		//	- until we receive the list of NEServices
		//	- until we get the session status of the NEService
		//	- at least 1s to ensure that the session status is valid
		//
		// Stop waiting:
		//	- after a timeout of 10s
		//	- if the list of NEServices doesn't contain the expected service
		//
		NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
    	while(keepRunning && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate])
    	{
			timeoutDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
			//NSLog(@"Waiting...");

			// Timeout after 10s
			if(startWaiting + 10.0 < CFAbsoluteTimeGetCurrent())
			{
				//NSLog(@"Timeout...");
				keepRunning = NO;
			}

			// Ensure we wait at least 1s
			if(startWaiting + 1.0 < CFAbsoluteTimeGetCurrent())
			{
				if(foundNEService != nil && (foundNEService.gotInitialSessionStatus))
				{
					//NSLog(@"Found NEService and session state");
					keepRunning = NO;
				}
			}
			else
			{
				//NSLog(@"Need to wait more...");
			}
		}
		if(foundNEService)
		{
			SCNetworkConnectionStatus currentState = foundNEService.state;
			//NSLog(@"Got status %@", GetDescriptionForSCNetworkConnectionStatus(currentState));

        

			if(shouldStartService)
			{
				if(currentState == kSCNetworkConnectionDisconnected)
				{
					// Connect
					[foundNEService connect];
					printf("connectionStartSuccess\n");
				}
				else
				{
					//printf(@"%@ was not started because it was in the state '%@'", vpnName, GetDescriptionForSCNetworkConnectionStatus(currentState));
					printf("connectionStartError-%s\n", [GetDescriptionForSCNetworkConnectionStatus(currentState) UTF8String]);
				}
			}
            else if (requireInfo) {
                printf("%s\n", [GetDescriptionForSCNetworkConnectionStatus(currentState) UTF8String]);
            }
			else
			{
				if(currentState == kSCNetworkConnectionConnected)
				{
					// Disconnect
					[foundNEService disconnect];
					printf("connectionStopSuccess\n");
				}
				else
				{
					printf("connectionStopError-%s\n"
                           , [GetDescriptionForSCNetworkConnectionStatus(currentState) UTF8String]);
				}
			}
		}
		else
		{
			printf("connectionNotFound\n");
		}
	}

	return 0;
}
