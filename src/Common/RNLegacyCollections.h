#import <Foundation/Foundation.h>

// Preserve dictionary subscript assignment semantics, including removal on nil.
static inline void RNSetDictionaryObject(NSMutableDictionary *dictionary, id<NSCopying> key, id value)
{
    if (value) [dictionary setObject:value forKey:key];
    else [dictionary removeObjectForKey:key];
}
