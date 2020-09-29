//
//  AudioUnitPlayer.h
//  ios-audio
//
//  Created by mac on 2020/9/25.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitPlayer : NSObject

-(id)initWithAudio:(NSString *)path;

-(void)start;


@end

NS_ASSUME_NONNULL_END
