#import "NSString+MORegEx.h"

@implementation NSString (MORegEx)

- (NSArray *)captureComponentsMatchedByRegex:(NSString *)pattern
{
#pragma clang diagnostic push
#pragma ide diagnostic ignored "NotReleasedValue"
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
#pragma clang diagnostic pop

    return [regex matchesInString:self options:0 range:NSMakeRange(0, [self length])];
}

- (NSString *)stringByReplacingOccurrencesOfRegex:(NSString *)pattern withString:(NSString *)replacementString
{
#pragma clang diagnostic push
#pragma ide diagnostic ignored "NotReleasedValue"
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
#pragma clang diagnostic pop

    NSString *updatedString = [regex stringByReplacingMatchesInString:self options:0 range:NSMakeRange(0, [self length]) withTemplate:replacementString];
    return updatedString;
}

- (BOOL)isMatchedByRegex:(NSString *)pattern
{
#pragma clang diagnostic push
#pragma ide diagnostic ignored "NotReleasedValue"
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
#pragma clang diagnostic pop
    
    NSUInteger matchCount = [regex numberOfMatchesInString:self options:0 range:NSMakeRange(0, [self length])];
    return (matchCount > 0);
}

@end
