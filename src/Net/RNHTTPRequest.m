#import "RNLegacyCollections.h"
#import "RNHTTPRequest.h"
#import "RNTLSSocket.h"
#import "RNCommon.h"

@interface RNHTTPRequest () {
    RNTLSSocket *_socket;
    BOOL _isCancelled;
    BOOL _isFinished;
    BOOL _timedOut;
    NSInteger _redirectCount;
}
@end

@implementation RNHTTPRequest

+ (instancetype)requestWithURLString:(NSString *)urlString
{
    RNHTTPRequest *req = [[self alloc] init];
    req.urlString = urlString;
    req.method = @"GET";
    req.connectTimeout = 15.0;
    req.readTimeout = 60.0;
    req.verifyTLS = YES; // Verify TLS certificates using embedded CA bundle
    return req;
}

- (void)start
{
    _redirectCount = 0;
    // One deadline covers DNS, redirects, TLS and a server that sends bytes
    // slowly enough to keep resetting an individual socket-read timeout.
    NSTimeInterval limit = self.readTimeout > 0 ? self.readTimeout : 60.0;
    __weak RNHTTPRequest *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(limit * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RNHTTPRequest *request = weakSelf;
        if (!request) return;
        RNTLSSocket *socket = nil;
        @synchronized (request) {
            if (request->_isFinished || request->_isCancelled) return;
            request->_timedOut = YES;
            socket = request->_socket;
        }
        [socket cancel];
        [request finishWithStatus:0 body:nil error:RNMakeError(RNErrorTimeout, @"Request timed out")];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self executeRequestForURL:self.urlString];
    });
}

- (void)cancel
{
    @synchronized (self) {
        if (_isCancelled || _isFinished) return;
        _isCancelled = YES;
        [_socket cancel];
    }
}

- (void)finishWithStatus:(NSInteger)status body:(NSData *)body error:(NSError *)error
{
    RNTLSSocket *socket = nil;
    BOOL timedOut = NO;
    @synchronized (self) {
        if (_isFinished) return;
        _isFinished = YES;
        timedOut = _timedOut;
        socket = _socket;
        _socket = nil;
        if (_timedOut) {
            status = 0; body = nil;
            error = RNMakeError(RNErrorTimeout, @"Request timed out");
        }
    }
    // Timeout cancellation only signals the socket. The worker still owns it
    // and must leave any TLS call before deallocation frees its TLS state.
    if (!timedOut) [socket close];
    _statusCode = status;
    RNMain(^{
        if (self.onComplete) {
            self.onComplete(status, body, error);
        }
    });
}

- (void)executeRequestForURL:(NSString *)currentURLString
{
    if (_isCancelled || self.isFinished) {
        [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorCancelled, @"Request cancelled")];
        return;
    }

    NSURL *url = [NSURL URLWithString:currentURLString];
    if (!url || !url.host) {
        [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorNetwork, [NSString stringWithFormat:@"Invalid URL: %@", currentURLString])];
        return;
    }

    BOOL isHTTPS = [url.scheme.lowercaseString isEqualToString:@"https"];
    NSInteger port = url.port ? url.port.integerValue : (isHTTPS ? 443 : 80);
    NSString *host = url.host;
    NSString *path = url.path.length ? url.path : @"/";
    // NSURL path strips trailing slashes, which causes redirect loops with web servers that enforce trailing slashes.
    // Preserve trailing slash if the original URL had one before any query string.
    NSString *urlWithoutQuery = [[currentURLString componentsSeparatedByString:@"?"] objectAtIndex:0];
    if ([urlWithoutQuery hasSuffix:@"/"] && ![path hasSuffix:@"/"]) {
        path = [path stringByAppendingString:@"/"];
    }
    if (url.query.length) {
        path = [NSString stringWithFormat:@"%@?%@", path, url.query];
    }

    RNTLSSocket *sock = [[RNTLSSocket alloc] init];
    sock.plain = !isHTTPS;
    @synchronized (self) {
        if (_isCancelled || _isFinished) return;
        _socket = sock;
    }

    NSError *err = nil;
    BOOL ok = [sock connectToHost:host
                             port:(int)port
                           verify:self.verifyTLS
                 connectTimeoutMs:(int)(self.connectTimeout * 1000)
                    readTimeoutMs:(int)(self.readTimeout * 1000)
                            error:&err];
    if (!ok) {
        [self finishWithStatus:0 body:nil error:err];
        return;
    }

    // Build HTTP request
    NSMutableString *head = [NSMutableString stringWithFormat:@"%@ %@ HTTP/1.1\r\n", self.method, path];
    [head appendFormat:@"Host: %@\r\n", host];
    [head appendString:@"User-Agent: Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1\r\n"];
    [head appendString:@"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,application/rss+xml,application/atom+xml,*/*;q=0.8\r\n"];
    [head appendString:@"Accept-Language: en-US,en;q=0.9,cs;q=0.8\r\n"];
    [head appendString:@"Connection: close\r\n"];

    for (NSString *key in self.headers) {
        [head appendFormat:@"%@: %@\r\n", key, [self.headers objectForKey:key]];
    }
    if (self.body.length) {
        [head appendFormat:@"Content-Length: %lu\r\n", (unsigned long)self.body.length];
    }
    [head appendString:@"\r\n"];

    NSMutableData *reqData = [NSMutableData dataWithData:[head dataUsingEncoding:NSUTF8StringEncoding]];
    if (self.body.length) {
        [reqData appendData:self.body];
    }

    if (![sock writeData:reqData error:&err]) {
        [self finishWithStatus:0 body:nil error:err];
        return;
    }

    // Read response headers
    NSMutableData *responseBuffer = [NSMutableData data];
    uint8_t buf[4096];
    NSRange headerEndRange = NSMakeRange(NSNotFound, 0);

    while (headerEndRange.location == NSNotFound) {
        if (_isCancelled) {
            [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorCancelled, @"Cancelled")];
            return;
        }
        NSInteger r = [sock readIntoBuffer:buf maxLength:sizeof(buf) error:&err];
        if (r < 0) {
            [self finishWithStatus:0 body:nil error:err];
            return;
        }
        if (r == 0) break; // EOF
        [responseBuffer appendBytes:buf length:r];

        // Search for \r\n\r\n
        const char *bytes = (const char *)responseBuffer.bytes;
        NSUInteger len = responseBuffer.length;
        for (NSUInteger i = 0; i + 3 < len; i++) {
            if (bytes[i] == '\r' && bytes[i+1] == '\n' && bytes[i+2] == '\r' && bytes[i+3] == '\n') {
                headerEndRange = NSMakeRange(0, i + 4);
                break;
            }
        }
    }

    if (headerEndRange.location == NSNotFound) {
        [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, @"Incomplete HTTP response headers")];
        return;
    }

    NSData *headerData = [responseBuffer subdataWithRange:NSMakeRange(0, headerEndRange.length - 4)];
    NSString *headerStr = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
    if (!headerStr) {
        headerStr = [[NSString alloc] initWithData:headerData encoding:NSISOLatin1StringEncoding];
    }

    NSArray *lines = [headerStr componentsSeparatedByString:@"\r\n"];
    if (!lines.count) {
        [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, @"Empty HTTP response")];
        return;
    }

    // Parse status line: HTTP/1.1 200 OK
    NSString *statusLine = [lines objectAtIndex:0];
    NSArray *parts = [statusLine componentsSeparatedByString:@" "];
    NSInteger status = (parts.count >= 2) ? [[parts objectAtIndex:1] integerValue] : 0;

    NSMutableDictionary *respHeaders = [NSMutableDictionary dictionary];
    for (NSUInteger i = 1; i < lines.count; i++) {
        NSString *line = [lines objectAtIndex:i];
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location != NSNotFound) {
            NSString *k = [[line substringToIndex:colon.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].lowercaseString;
            NSString *v = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            RNSetDictionaryObject(respHeaders, k, v);
        }
    }
    _responseHeaders = [respHeaders copy];

    // Handle redirects (301, 302, 303, 307, 308)
    if ((status == 301 || status == 302 || status == 303 || status == 307 || status == 308) && [respHeaders objectForKey:@"location"]) {
        if (_redirectCount >= 10) {
            [self finishWithStatus:status body:nil error:RNMakeError(RNErrorBadResponse, @"Too many HTTP redirects")];
            return;
        }
        _redirectCount++;
        NSString *loc = [respHeaders objectForKey:@"location"];
        NSURL *nextURL = [NSURL URLWithString:loc relativeToURL:url];
        [sock close];
        RNLog(@"Redirecting (%ld) to %@", (long)status, nextURL.absoluteString);
        [self executeRequestForURL:nextURL.absoluteString];
        return;
    }

    // Process body
    NSUInteger bodyOffset = headerEndRange.length;
    NSMutableData *bodyData = [NSMutableData data];
    if (responseBuffer.length > bodyOffset) {
        [bodyData appendBytes:(const char *)responseBuffer.bytes + bodyOffset length:responseBuffer.length - bodyOffset];
    }

    NSString *transferEncoding = [respHeaders objectForKey:@"transfer-encoding"];
    BOOL isChunked = [transferEncoding.lowercaseString isEqualToString:@"chunked"];
    long long contentLength = [respHeaders objectForKey:@"content-length"] ? [[respHeaders objectForKey:@"content-length"] longLongValue] : -1;

    // Read remaining body until EOF or length
    while (YES) {
        if (_isCancelled) {
            [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorCancelled, @"Cancelled")];
            return;
        }
        if (!isChunked && contentLength >= 0 && (unsigned long long)bodyData.length >= (unsigned long long)contentLength) {
            break;
        }
        NSInteger r = [sock readIntoBuffer:buf maxLength:sizeof(buf) error:&err];
        if (r < 0) {
            [self finishWithStatus:0 body:nil error:err];
            return;
        }
        if (r == 0) break; // EOF
        [bodyData appendBytes:buf length:r];
    }
    if (!isChunked && contentLength >= 0 && (unsigned long long)bodyData.length < (unsigned long long)contentLength) {
        [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, L(@"InvalidHTTPBody"))];
        return;
    }

    // Decode chunked encoding if present
    if (isChunked) {
        NSMutableData *decoded = [NSMutableData data];
        const uint8_t *b = (const uint8_t *)bodyData.bytes;
        NSUInteger total = bodyData.length;
        NSUInteger pos = 0;
        BOOL terminated = NO;

        while (pos < total) {
            // Find CRLF of chunk size line
            NSUInteger lineEnd = NSNotFound;
            for (NSUInteger i = pos; i + 1 < total; i++) {
                if (b[i] == '\r' && b[i+1] == '\n') {
                    lineEnd = i;
                    break;
                }
            }
            if (lineEnd == NSNotFound) {
                [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, L(@"InvalidHTTPBody"))];
                return;
            }

            NSString *sizeStr = [[NSString alloc] initWithBytes:b + pos length:lineEnd - pos encoding:NSASCIIStringEncoding];
            if (!sizeStr.length) {
                [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, L(@"InvalidHTTPBody"))];
                return;
            }
            NSRange extension = [sizeStr rangeOfString:@";"];
            NSUInteger digitCount = extension.location == NSNotFound ? sizeStr.length : extension.location;
            NSUInteger chunkSize = 0;
            BOOL validSize = digitCount > 0;
            for (NSUInteger i = 0; validSize && i < digitCount; i++) {
                unichar c = [sizeStr characterAtIndex:i];
                NSUInteger digit;
                if (c >= '0' && c <= '9') digit = c - '0';
                else if (c >= 'a' && c <= 'f') digit = c - 'a' + 10;
                else if (c >= 'A' && c <= 'F') digit = c - 'A' + 10;
                else { validSize = NO; break; }
                if (chunkSize > (NSUIntegerMax - digit) / 16) { validSize = NO; break; }
                chunkSize = chunkSize * 16 + digit;
            }
            if (!validSize) {
                [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, L(@"InvalidHTTPBody"))];
                return;
            }

            pos = lineEnd + 2;
            if (chunkSize == 0) {
                // Trailers end with an empty CRLF line, including when there are none.
                while (total - pos >= 2) {
                    NSUInteger trailerEnd = pos;
                    while (trailerEnd < total - 1 &&
                           !(b[trailerEnd] == '\r' && b[trailerEnd + 1] == '\n')) trailerEnd++;
                    if (trailerEnd >= total - 1) break;
                    if (trailerEnd == pos) { terminated = YES; break; }
                    pos = trailerEnd + 2;
                }
                break;
            }
            if (chunkSize > total - pos) {
                [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, L(@"InvalidHTTPBody"))];
                return;
            }
            [decoded appendBytes:b + pos length:chunkSize];
            pos += chunkSize;
            if (total - pos >= 2 && b[pos] == '\r' && b[pos+1] == '\n') {
                pos += 2;
            } else {
                [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, L(@"InvalidHTTPBody"))];
                return;
            }
        }
        if (!terminated) {
            [self finishWithStatus:0 body:nil error:RNMakeError(RNErrorBadResponse, L(@"InvalidHTTPBody"))];
            return;
        }
        bodyData = decoded;
    }

    [self finishWithStatus:status body:bodyData error:nil];
}

@end
