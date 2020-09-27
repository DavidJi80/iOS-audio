//
//  AudioController.h
//  ios-audio
//
//  Created by mac on 2020/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioController : NSObject

+ (AudioController *)sharedAudioManager;

//开启 Audio Unit
- (void)start;

//关闭 Audio Unit
- (void)stop;

//结束 Audio Unit
- (void)finished;

@end

NS_ASSUME_NONNULL_END
