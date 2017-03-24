// AFNetworkActivityConsoleLogger.h
//
// Copyright (c) 2015 AFNetworking (http://afnetworking.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFNetworkActivityConsoleLogger.h"

@implementation AFNetworkActivityConsoleLogger

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.level = AFLoggerLevelInfo;

    return self;
}


- (void)URLSessionTaskDidStart:(NSURLSessionTask *)task {
    NSURLRequest *request = task.originalRequest;

    NSString *body = nil;
    if ([request HTTPBody]) {
        body = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
    }

    switch (self.level) {
        case AFLoggerLevelDebug:
            NSLog(@"%@ '%@': %@ %@", [request HTTPMethod], [[request URL] absoluteString], [request allHTTPHeaderFields], body);
            break;
        case AFLoggerLevelInfo:
            NSLog(@"%@ '%@'", [request HTTPMethod], [[request URL] absoluteString]);
            break;
        default:
            break;
    }
}

- (void)URLSessionTaskDidFinish:(NSURLSessionTask *)task withResponseObject:(id)responseObject inElapsedTime:(NSTimeInterval )elapsedTime withError:(NSError *)error {
    NSUInteger responseStatusCode = 0;
    NSDictionary *responseHeaderFields = nil;
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        responseStatusCode = (NSUInteger)[(NSHTTPURLResponse *)task.response statusCode];
        responseHeaderFields = [(NSHTTPURLResponse *)task.response allHeaderFields];
    }

    if (error) {
        switch (self.level) {
            case AFLoggerLevelDebug:
            case AFLoggerLevelInfo:
            case AFLoggerLevelError:
                NSLog(@"[Error] %@ '%@' (%ld) [%.04f s]: %@", [task.originalRequest HTTPMethod], [[task.response URL] absoluteString], (long)responseStatusCode, elapsedTime, error);
            default:
                break;
        }
    } else {
        
        [self logTaskToFile:task withResponseObject:responseObject];

        switch (self.level) {
            case AFLoggerLevelDebug:
                NSLog(@"%ld '%@' [%.04f s]: %@ %@", (long)responseStatusCode, [[task.response URL] absoluteString], elapsedTime, responseHeaderFields, responseObject);
                break;
            case AFLoggerLevelInfo:
                NSLog(@"%ld '%@' [%.04f s]", (long)responseStatusCode, [[task.response URL] absoluteString], elapsedTime);
                break;
            default:
                break;
        }
    }
}

- (void)logTaskToFile:(NSURLSessionTask *)task withResponseObject:(id)responseObject {

    NSURL *url = [task.response URL];

    NSString *folderName = [self getFolderNameForURL:url];

    NSString *folderComponent = [NSString stringWithFormat:@"Documents/%@", folderName];

    NSString *folder =  [NSHomeDirectory() stringByAppendingPathComponent:folderComponent];

    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];

    // NSTimeInterval is defined as double
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];

    NSString *timeStampString = [[NSNumber numberWithDouble:timeStamp] stringValue];
    NSString *responseJsonFileName = [NSString stringWithFormat:@"response_%@.json", timeStampString];
    NSString *requestJsonFileName = [NSString stringWithFormat:@"request_%@.json", timeStampString];


    NSString *responseJSONPath = [folder stringByAppendingPathComponent:responseJsonFileName];

    if (responseObject && [responseObject respondsToSelector:@selector(jsonObject)]) {
        
        NSString *responseString = [NSString stringWithFormat:@"%@", responseObject];
        
        NSDictionary *jsonObject = [responseObject performSelector:@selector(jsonObject)];
        
        if (jsonObject && [jsonObject isKindOfClass:[NSDictionary class]]) {
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject
                                                               options:NSJSONWritingPrettyPrinted
                                                                 error:&error];
            
            responseString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
        
        
        NSString *prettyResponseString = [self convertToPrettyJSON:responseString];

        [prettyResponseString writeToFile:responseJSONPath
                               atomically:YES
                                 encoding:NSUTF8StringEncoding
                                    error:NULL];
    }


    if (task.originalRequest.HTTPBody) {

        NSString *requestJSONPath = [folder stringByAppendingPathComponent:requestJsonFileName];

        NSData *requestBodyData = task.originalRequest.HTTPBody;

        NSData *requestPrettyData = [self getPrettyDataFromRequestData:requestBodyData];

        [requestPrettyData writeToFile:requestJSONPath
                            atomically:YES];
    }

}

- (NSData *)getPrettyDataFromRequestData:(NSData *)requestBodyData {
//data --> NSDictionary --> pretty json
    NSDictionary *requestDictionary = [NSJSONSerialization JSONObjectWithData:requestBodyData options:0 error:nil];
    NSData *requestPrettyData = [NSJSONSerialization dataWithJSONObject:requestDictionary options:NSJSONWritingPrettyPrinted error:nil];
    return requestPrettyData;
}

- (NSString *)convertToPrettyJSON:(NSString *)responseString {
    NSDictionary *prettyResponseDictionary = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    if (!prettyResponseDictionary) {
        return responseString;
    }

    NSData *jsonData =
            [NSJSONSerialization dataWithJSONObject:prettyResponseDictionary
                                            options:NSJSONWritingPrettyPrinted
                                              error:nil];
    NSString *prettyResponseString =
            [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return prettyResponseString;
}

- (NSString *)getFolderNameForURL:(NSURL *)url {
    NSString *host = [url host];
    NSString *path = [url path];

    //compose folder name
    NSString *folderName = [NSString stringWithFormat:@"%@_%@", host, [path stringByReplacingOccurrencesOfString:@"/" withString:@"_"]];
    return folderName;
}
@end
