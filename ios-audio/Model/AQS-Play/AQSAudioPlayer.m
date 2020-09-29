//
//  AQSAudioPlayer.m
//  ios-audio
//
//  Created by mac on 2020/9/24.
//

#import "AQSAudioPlayer.h"

@implementation AQSAudioPlayer


// 播放音频队列回调
static void HandleOutputBuffer (
                                void                 *aqData,   // 1. 自定义结构(AQPlayerState,包含音频队列的状态信息)
                                AudioQueueRef        inAQ,      // 2. 拥有此回调的音频队列
                                AudioQueueBufferRef  inBuffer   // 3. 音频队列缓冲区
){
    AQSAudioPlayer *pAqData = (__bridge AQSAudioPlayer *)(aqData);        // 1
    if (pAqData->mIsRunning == 0) return;                     // 2
    UInt32 numBytesReadFromFile;                              // 3
    UInt32 numPackets = pAqData->mNumPacketsToRead;           // 4
    OSStatus status=AudioFileReadPackets(                            // 1
                            pAqData->mAudioFile,        // 2
                            false,                      // 3
                            &numBytesReadFromFile,      // 4
                            pAqData->mPacketDescs,      // 5
                            pAqData->mCurrentPacket,    // 6
                            &numPackets,                // 7
                            inBuffer->mAudioData        // 8
                            );
    if(status!=noErr)return;
    NSLog(@"%lld,%d",pAqData->mCurrentPacket,numPackets);
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

void DeriveBufferSizeAndNumPacketsToRead (
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



-(id)initWithAudio:(NSString *)path{
    //4.1
    CFURLRef audioFileURL =(__bridge CFURLRef)[NSURL fileURLWithPath:path];
    
    //4.2
    OSStatus status=AudioFileOpenURL(                           // 2
                                     audioFileURL,              // 3
                                     kAudioFileReadPermission,  // 4
                                     0,                         // 5
                                     &mAudioFile                // 6
                                     );
    if (status != noErr) {//错误处理
        NSLog(@"*** Error *** PlayAudio - play:Path: could not open audio file. Path given was: %@", path);
    }
    CFRelease (audioFileURL);                                   // 7
    
    //4.3
    UInt32 dataFormatSize = sizeof (mDataFormat);           // 1
    AudioFileGetProperty (                                  // 2
        mAudioFile,                                         // 3
        kAudioFilePropertyDataFormat,                       // 4
        &dataFormatSize,                                    // 5
        &mDataFormat                                        // 6
    );

    //5.
    //将OC对象的所有权（ownership）桥接给CF对象
    //void * inUserData=(void *)CFBridgingRetain(self);
    void * inUserData=(__bridge_retained void *)(self);
    AudioQueueNewOutput (                                // 1
        &mDataFormat,                                    // 2
        HandleOutputBuffer,                              // 3
        inUserData,                                      // 4
//        nil,                                             // 5
//        nil,                                             // 6
        CFRunLoopGetCurrent (),                          // 5
        kCFRunLoopCommonModes,                           // 6
        0,                                               // 7
        &mQueue                                          // 8
    );
    
    //6.1.
    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof (maxPacketSize);
    AudioFileGetProperty (                               // 1
        mAudioFile,                                      // 2
        kAudioFilePropertyPacketSizeUpperBound,          // 3
        &propertySize,                                   // 4
        &maxPacketSize                                   // 5
    );
    
    DeriveBufferSizeAndNumPacketsToRead (                // 6
        mDataFormat,                                     // 7
        maxPacketSize,                                   // 8
        0.5,                                             // 9
        &bufferByteSize,                                 // 10
        &mNumPacketsToRead                               // 11
    );
    
    //6.2.
    bool isFormatVBR = (                                       // 1
        mDataFormat.mBytesPerPacket == 0 ||
        mDataFormat.mFramesPerPacket == 0
    );
     
    if (isFormatVBR) {                                         // 2
        mPacketDescs =
          (AudioStreamPacketDescription*) malloc (
            mNumPacketsToRead * sizeof (AudioStreamPacketDescription)
          );
    } else {                                                   // 3
        mPacketDescs = NULL;
    }

    //7.
    UInt32 cookieSize = sizeof (UInt32);                   // 1
    bool couldNotGetProperty =                             // 2
        AudioFileGetPropertyInfo (                         // 3
            mAudioFile,                                    // 4
            kAudioFilePropertyMagicCookieData,             // 5
            &cookieSize,                                   // 6
            NULL                                           // 7
        );
    
    if (!couldNotGetProperty && cookieSize) {              // 8
        char* magicCookie =
            (char *) malloc (cookieSize);
     
        AudioFileGetProperty (                             // 9
            mAudioFile,                                    // 10
            kAudioFilePropertyMagicCookieData,             // 11
            &cookieSize,                                   // 12
            magicCookie                                    // 13
        );
     
        AudioQueueSetProperty (                            // 14
            mQueue,                                        // 15
            kAudioQueueProperty_MagicCookie,               // 16
            magicCookie,                                   // 17
            cookieSize                                     // 18
        );
     
        free (magicCookie);                                // 19
    }
    
    //8.
    mCurrentPacket = 0;                                     // 1
    mIsRunning = true;                                      // 1
     
    for (int i = 0; i < kNumberBuffers; ++i) {              // 2
        AudioQueueAllocateBuffer (                          // 3
            mQueue,                                         // 4
            bufferByteSize,                                 // 5
            &mBuffers[i]                                    // 6
        );
     
        HandleOutputBuffer (                                // 7
            (__bridge_retained void *)(self),               // 8
            mQueue,                                         // 9
            mBuffers[i]                                     // 10
        );
    }
    
    //9.
    Float32 gain = 1.0;                                 // 1
        // Optionally, allow user to override gain setting here
    AudioQueueSetParameter (                            // 2
                            mQueue,                     // 3
                            kAudioQueueParam_Volume,    // 4
                            gain                        // 5
    );
    
    AudioQueueStart (           // 2
                     mQueue,    // 3
                     NULL       // 4
    );
    
    return self;
}

@end
