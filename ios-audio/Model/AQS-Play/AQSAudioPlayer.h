//
//  AQSAudioPlayer.h
//  ios-audio
//
//  Created by mac on 2020/9/24.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

static const int kNumberBuffers = 3;                              // 1. 音频队列缓冲区的数量

@interface AQSAudioPlayer : NSObject{
    AudioStreamBasicDescription   mDataFormat;                    // 2. 音频流的音频数据格式
    AudioQueueRef                 mQueue;                         // 3. 播放音频队列
    AudioQueueBufferRef           mBuffers[kNumberBuffers];       // 4. 指向音频队列缓冲区的指针
    AudioFileID                   mAudioFile;                     // 5. 音频文件对象
    UInt32                        bufferByteSize;                 // 6. 音频队列缓冲区的字节大小
    SInt64                        mCurrentPacket;                 // 7. 音频文件中要播放的数据包索引
    UInt32                        mNumPacketsToRead;              // 8. 回调时要读取的数据包数
    AudioStreamPacketDescription  *mPacketDescs;                  // 9. VBR:数据包描述的数组,CBR:NULL
    bool                          mIsRunning;                     // 10. 音频队列是否正在运行
}

//播放方法定义
-(id)initWithAudio:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
