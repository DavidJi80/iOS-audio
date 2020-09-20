//
//  AQSPlayViewController.m
//  ios-audio
//
//  Created by mac on 2020/9/19.
//

#import "AQSPlayViewController.h"


static const int kNumberBuffers = 3;                              // 1. 音频队列缓冲区的数量
typedef struct _AQPlayerState {
    AudioStreamBasicDescription   mDataFormat;                    // 2. 音频流的音频数据格式
    AudioQueueRef                 mQueue;                         // 3. 播放音频队列
    AudioQueueBufferRef           mBuffers[kNumberBuffers];       // 4. 指向音频队列缓冲区的指针
    AudioFileID                   mAudioFile;                     // 5. 音频文件对象
    UInt32                        bufferByteSize;                 // 6. 音频队列缓冲区的字节大小
    SInt64                        mCurrentPacket;                 // 7. 音频文件中要播放的数据包索引
    UInt32                        mNumPacketsToRead;              // 8. 回调时要读取的数据包数
    AudioStreamPacketDescription  *mPacketDescs;                  // 9. VBR:数据包描述的数组,CBR:NULL
    bool                          mIsRunning;                     // 10. 音频队列是否正在运行
} AQPlayerState;

// 播放音频队列回调
static void HandleOutputBuffer (
                                void                 *aqData,                 // 1. 自定义结构(AQPlayerState,包含音频队列的状态信息)
                                AudioQueueRef        inAQ,                    // 2. 拥有此回调的音频队列
                                AudioQueueBufferRef  inBuffer                 // 3. 音频队列缓冲区
){
    AQPlayerState *pAqData = (AQPlayerState *) aqData;        // 1
    if (pAqData->mIsRunning == 0) return;                     // 2
    UInt32 numBytesReadFromFile;                              // 3
    UInt32 numPackets = pAqData->mNumPacketsToRead;           // 4
    AudioFileReadPackets(                            // 1
                            pAqData->mAudioFile,        // 2
                            false,                      // 3
                            &numBytesReadFromFile,      // 4
                            pAqData->mPacketDescs,      // 5
                            pAqData->mCurrentPacket,    // 6
                            &numPackets,                // 7
                            inBuffer->mAudioData        // 8
                            );
    if (numPackets > 0) {                                     // 5
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;  // 6
        AudioQueueEnqueueBuffer (                                           // 1
                                 pAqData->mQueue,                           // 2
                                 inBuffer,                                  // 3
                                 (pAqData->mPacketDescs ? numPackets : 0),  // 4
                                 pAqData->mPacketDescs                      // 5
                                 );
        pAqData->mCurrentPacket += numPackets;                // 7
    } else {
        AudioQueueStop (
                        pAqData->mQueue,
                        false
                        );
        pAqData->mIsRunning = false;
    }
}

void DeriveBufferSize (
    AudioStreamBasicDescription ASBDesc,                             // 1
    UInt32                      maxPacketSize,                       // 2
    Float64                     seconds,                             // 3
    UInt32                      *outBufferSize,                      // 4
    UInt32                      *outNumPacketsToRead                 // 5
) {
    static const int maxBufferSize = 0x50000;                        // 6
    static const int minBufferSize = 0x4000;                         // 7
 
    if (ASBDesc.mFramesPerPacket != 0) {                             // 8
        Float64 numPacketsForTime =
            ASBDesc.mSampleRate / ASBDesc.mFramesPerPacket * seconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {                                                         // 9
        *outBufferSize =
            maxBufferSize > maxPacketSize ?
                maxBufferSize : maxPacketSize;
    }
 
    if (                                                             // 10
        *outBufferSize > maxBufferSize &&
        *outBufferSize > maxPacketSize
    )
        *outBufferSize = maxBufferSize;
    else {                                                           // 11
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
 
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;           // 12
}

@interface AQSPlayViewController (){
    AQPlayerState aqData;
}

@end

@implementation AQSPlayViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    [self playAudio];
}

-(void)playAudio{
    //4.1
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"1" ofType:@"mp3"];
    CFURLRef audioFileURL =(__bridge CFURLRef)[NSURL fileURLWithPath:filePath];
    
    //4.2
    OSStatus status=AudioFileOpenURL(                           // 2
                                     audioFileURL,              // 3
                                     kAudioFileReadPermission,  // 4
                                     0,                         // 5
                                     &aqData.mAudioFile         // 6
                                     );
    if (status != noErr) {//错误处理
        NSLog(@"*** Error *** PlayAudio - play:Path: could not open audio file. Path given was: %@", filePath);
    }
    CFRelease (audioFileURL);                                   // 7
    
    //4.3
    UInt32 dataFormatSize = sizeof (aqData.mDataFormat);    // 1
    AudioFileGetProperty (                                  // 2
        aqData.mAudioFile,                                  // 3
        kAudioFilePropertyDataFormat,                       // 4
        &dataFormatSize,                                    // 5
        &aqData.mDataFormat                                 // 6
    );
    
    //5.
    AudioQueueNewOutput (                                // 1
        &aqData.mDataFormat,                             // 2
        HandleOutputBuffer,                              // 3
        &aqData,                                         // 4
        CFRunLoopGetCurrent (),                          // 5
        kCFRunLoopCommonModes,                           // 6
        0,                                               // 7
        &aqData.mQueue                                   // 8
    );
    
    //6.1.
    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof (maxPacketSize);
    AudioFileGetProperty (                               // 1
        aqData.mAudioFile,                               // 2
        kAudioFilePropertyPacketSizeUpperBound,          // 3
        &propertySize,                                   // 4
        &maxPacketSize                                   // 5
    );
    
    DeriveBufferSize (                                   // 6
        aqData.mDataFormat,                              // 7
        maxPacketSize,                                   // 8
        0.5,                                             // 9
        &aqData.bufferByteSize,                          // 10
        &aqData.mNumPacketsToRead                        // 11
    );
    
    //6.2.
    bool isFormatVBR = (                                       // 1
        aqData.mDataFormat.mBytesPerPacket == 0 ||
        aqData.mDataFormat.mFramesPerPacket == 0
    );
     
    if (isFormatVBR) {                                         // 2
        aqData.mPacketDescs =
          (AudioStreamPacketDescription*) malloc (
            aqData.mNumPacketsToRead * sizeof (AudioStreamPacketDescription)
          );
    } else {                                                   // 3
        aqData.mPacketDescs = NULL;
    }
    
    //7.
    UInt32 cookieSize = sizeof (UInt32);                   // 1
    bool couldNotGetProperty =                             // 2
        AudioFileGetPropertyInfo (                         // 3
            aqData.mAudioFile,                             // 4
            kAudioFilePropertyMagicCookieData,             // 5
            &cookieSize,                                   // 6
            NULL                                           // 7
        );
    
    if (!couldNotGetProperty && cookieSize) {              // 8
        char* magicCookie =
            (char *) malloc (cookieSize);
     
        AudioFileGetProperty (                             // 9
            aqData.mAudioFile,                             // 10
            kAudioFilePropertyMagicCookieData,             // 11
            &cookieSize,                                   // 12
            magicCookie                                    // 13
        );
     
        AudioQueueSetProperty (                            // 14
            aqData.mQueue,                                 // 15
            kAudioQueueProperty_MagicCookie,               // 16
            magicCookie,                                   // 17
            cookieSize                                     // 18
        );
     
        free (magicCookie);                                // 19
    }
    
    //8.
    aqData.mCurrentPacket = 0;                                // 1
     
    for (int i = 0; i < kNumberBuffers; ++i) {                // 2
        AudioQueueAllocateBuffer (                            // 3
            aqData.mQueue,                                    // 4
            aqData.bufferByteSize,                            // 5
            &aqData.mBuffers[i]                               // 6
        );
     
        HandleOutputBuffer (                                  // 7
            &aqData,                                          // 8
            aqData.mQueue,                                    // 9
            aqData.mBuffers[i]                                // 10
        );
    }
    
    //9.
    Float32 gain = 1.0;                                       // 1
        // Optionally, allow user to override gain setting here
    AudioQueueSetParameter (                                  // 2
        aqData.mQueue,                                        // 3
        kAudioQueueParam_Volume,                              // 4
        gain                                                  // 5
    );
    
    //10.
    aqData.mIsRunning = true;                          // 1
     
    AudioQueueStart (                                  // 2
        aqData.mQueue,                                 // 3
        NULL                                           // 4
    );
     
//    do {                                               // 5
//        CFRunLoopRunInMode (                           // 6
//            kCFRunLoopDefaultMode,                     // 7
//            0.25,                                      // 8
//            false                                      // 9
//        );
//    } while (aqData.mIsRunning);
//
//    CFRunLoopRunInMode (                               // 10
//        kCFRunLoopDefaultMode,
//        1,
//        false
//    );
}

@end
