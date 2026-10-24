#import "RNReadabilityExtractor.h"
#import "RNHTTPRequest.h"
#import "RNUtils.h"
#import "RNCommon.h"
#import "RNFeedStore.h"

@implementation RNReadabilityResult
@end

@implementation RNReadabilityExtractor

+ (void)extractArticleFromURL:(NSString *)urlString completion:(RNReadabilityCompletion)completion
{
    if (!urlString.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"RNReadability" code:-1 userInfo:@{ NSLocalizedDescriptionKey: @"Empty URL" }]);
        return;
    }

    RNHTTPRequest *req = [RNHTTPRequest requestWithURLString:urlString];
    req.connectTimeout = [RNFeedStore sharedStore].networkTimeout;
    req.readTimeout = [RNFeedStore sharedStore].networkTimeout;
    req.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
        if (error || status < 200 || status >= 400 || body.length == 0) {
            if (completion) completion(nil, error ? error : [NSError errorWithDomain:@"RNReadability" code:status userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP status %ld", (long)status] }]);
            return;
        }

        NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        if (!html) {
            // Fallback to Windows-1250 / ISO-8859-2 / Latin-1 for older Czech/European news sites
            html = [[NSString alloc] initWithData:body encoding:NSWindowsCP1250StringEncoding];
            if (!html) html = [[NSString alloc] initWithData:body encoding:NSISOLatin1StringEncoding];
        }

        if (!html.length) {
            if (completion) completion(nil, [NSError errorWithDomain:@"RNReadability" code:-2 userInfo:@{ NSLocalizedDescriptionKey: @"Failed to decode page HTML" }]);
            return;
        }

        RNReadabilityResult *res = [self extractArticleFromHTML:html baseURL:urlString];
        if (completion) completion(res, nil);
    };
    [req start];
}

+ (NSString *)cleanStringByRemovingPattern:(NSString *)pattern fromString:(NSString *)str
{
    if (!str.length) return @"";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                                             error:NULL];
    return [regex stringByReplacingMatchesInString:str options:0 range:NSMakeRange(0, str.length) withTemplate:@""];
}

+ (NSString *)firstMatchForPattern:(NSString *)pattern inString:(NSString *)str groupIndex:(NSUInteger)groupIndex
{
    if (!str.length) return nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                                             error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:str options:0 range:NSMakeRange(0, str.length)];
    if (match && match.numberOfRanges > groupIndex) {
        NSRange r = [match rangeAtIndex:groupIndex];
        if (r.location != NSNotFound) {
            return [str substringWithRange:r];
        }
    }
    return nil;
}

+ (NSString *)resolveURL:(NSString *)rel withBase:(NSString *)base
{
    if (!rel.length) return @"";
    if ([rel hasPrefix:@"http://"] || [rel hasPrefix:@"https://"] || [rel hasPrefix:@"data:"]) {
        return rel;
    }
    NSURL *baseURL = [NSURL URLWithString:base];
    if (!baseURL) return rel;
    NSURL *resolved = [NSURL URLWithString:rel relativeToURL:baseURL];
    return resolved.absoluteString.length ? resolved.absoluteString : rel;
}

+ (RNReadabilityResult *)extractArticleFromHTML:(NSString *)rawHTML baseURL:(NSString *)baseURL
{
    if (!rawHTML.length) return nil;

    RNReadabilityResult *res = [[RNReadabilityResult alloc] init];

    // 1. Extract og:title or <title>
    NSString *ogTitle = [self firstMatchForPattern:@"<meta[^>]+property=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)[\"']" inString:rawHTML groupIndex:1];
    if (!ogTitle.length) {
        ogTitle = [self firstMatchForPattern:@"<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:title[\"']" inString:rawHTML groupIndex:1];
    }
    if (!ogTitle.length) {
        ogTitle = [self firstMatchForPattern:@"<title[^>]*>([^<]+)</title>" inString:rawHTML groupIndex:1];
    }
    res.title = [RNUtils cleanString:ogTitle];

    // 2. Extract Lead Image (og:image or twitter:image)
    NSString *leadImg = [self firstMatchForPattern:@"<meta[^>]+property=[\"']og:image[\"'][^>]+content=[\"']([^\"']+)[\"']" inString:rawHTML groupIndex:1];
    if (!leadImg.length) {
        leadImg = [self firstMatchForPattern:@"<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:image[\"']" inString:rawHTML groupIndex:1];
    }
    if (!leadImg.length) {
        leadImg = [self firstMatchForPattern:@"<meta[^>]+name=[\"']twitter:image[\"'][^>]+content=[\"']([^\"']+)[\"']" inString:rawHTML groupIndex:1];
    }
    if (leadImg.length) {
        res.leadImageURL = [self resolveURL:leadImg withBase:baseURL];
    }

    // 3. Strip non-content blocks
    NSString *html = rawHTML;
    html = [self cleanStringByRemovingPattern:@"<!--[\\s\\S]*?-->" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<script[\\s\\S]*?</script>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<style[\\s\\S]*?</style>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<noscript[\\s\\S]*?</noscript>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<header[\\s\\S]*?</header>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<footer[\\s\\S]*?</footer>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<nav[\\s\\S]*?</nav>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<aside[\\s\\S]*?</aside>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<form[\\s\\S]*?</form>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<svg[\\s\\S]*?</svg>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<button[\\s\\S]*?</button>" fromString:html];
    html = [self cleanStringByRemovingPattern:@"<iframe[\\s\\S]*?</iframe>" fromString:html];

    // 4. Look for article container
    NSString *candidateBody = nil;

    // Pattern A: <article>...</article>
    NSString *articleTag = [self firstMatchForPattern:@"<article[^>]*>([\\s\\S]*?)</article>" inString:html groupIndex:1];
    if (articleTag.length > 200) {
        candidateBody = articleTag;
    }

    // Pattern B: <div class/id="*article*|*story*|*entry-content*|*post-body*">...</div>
    if (!candidateBody) {
        NSString *divMatch = [self firstMatchForPattern:@"<div[^>]+(?:class|id)=[\"'][^\"']*(?:article-body|story-body|entry-content|post-body|art-body|content-article|article__body|article__text|article-text|b-article__body)[^\"']*[\"'][^>]*>([\\s\\S]*?)</div>" inString:html groupIndex:1];
        if (divMatch.length > 200) {
            candidateBody = divMatch;
        }
    }

    // 5. Paragraph extraction & cleanup
    NSMutableString *cleanContent = [NSMutableString string];

    // If we have a valid lead image (not SVG), insert it at top
    if (res.leadImageURL.length > 0 && ![res.leadImageURL.lowercaseString hasSuffix:@".svg"]) {
        [cleanContent appendFormat:@"<p><img src=\"%@\" class=\"lead-image\" alt=\"\" onerror=\"this.style.display='none'\" /></p>\n", res.leadImageURL];
    }

    NSString *sourceForParagraphs = candidateBody.length ? candidateBody : html;

    // Extract all <p>...</p> tags
    NSRegularExpression *pRegex = [NSRegularExpression regularExpressionWithPattern:@"<p[^>]*>([\\s\\S]*?)</p>"
                                                                            options:NSRegularExpressionCaseInsensitive
                                                                              error:NULL];
    NSArray *pMatches = [pRegex matchesInString:sourceForParagraphs options:0 range:NSMakeRange(0, sourceForParagraphs.length)];

    NSUInteger keptParagraphs = 0;
    for (NSTextCheckingResult *m in pMatches) {
        if (m.numberOfRanges > 1) {
            NSString *pInner = [sourceForParagraphs substringWithRange:[m rangeAtIndex:1]];
            // Strip tags to check text length
            NSString *plain = [RNUtils stripHTML:pInner];
            plain = [plain stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            // Keep substantive paragraphs or paragraphs containing an image
            if (plain.length >= 25 || [pInner rangeOfString:@"<img" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                pInner = [self cleanStringByRemovingPattern:@"<svg[\\s\\S]*?</svg>" fromString:pInner];
                pInner = [self cleanStringByRemovingPattern:@"<button[\\s\\S]*?</button>" fromString:pInner];

                // Fix relative image links inside paragraph
                NSRegularExpression *imgSrcRegex = [NSRegularExpression regularExpressionWithPattern:@"<img[^>]+src=[\"']([^\"']+)[\"']"
                                                                                             options:NSRegularExpressionCaseInsensitive
                                                                                               error:NULL];
                NSArray *imgs = [imgSrcRegex matchesInString:pInner options:0 range:NSMakeRange(0, pInner.length)];
                for (NSTextCheckingResult *im in imgs) {
                    if (im.numberOfRanges > 1) {
                        NSString *rawSrc = [pInner substringWithRange:[im rangeAtIndex:1]];
                        NSString *absSrc = [self resolveURL:rawSrc withBase:baseURL];
                        pInner = [pInner stringByReplacingOccurrencesOfString:rawSrc withString:absSrc];
                    }
                }

                [cleanContent appendFormat:@"<p>%@</p>\n", pInner];
                keptParagraphs++;
            }
        }
    }

    // Fallback: If no good paragraphs found, use sanitized candidateBody or snippet
    if (keptParagraphs == 0) {
        if (candidateBody.length) {
            [cleanContent appendString:candidateBody];
        } else {
            [cleanContent appendString:@"<p>(Celý text článku se nepodařilo z webové stránky extrahovat. Otevřete článek v Safari.)</p>"];
        }
    }

    res.contentHTML = cleanContent;
    return res;
}

@end
