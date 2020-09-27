//
//  AudioUnitPlayer.h
//  ios-audio
//
//  Created by mac on 2020/9/25.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitPlayer : NSObject{
    AudioStreamBasicDescription   mDataFormat;                    // 2. 音频流的音频数据格式
    AudioFileID                   mAudioFile;                     // 5. 音频文件对象
}

@property (nonatomic, assign) double graphSampleRate;

//播放方法定义
-(id)initWithAudio:(NSString *)path;


@end

NS_ASSUME_NONNULL_END
